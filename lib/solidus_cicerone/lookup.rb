# frozen_string_literal: true

require "solidus_cicerone/event_payload"
require "solidus_cicerone/ids"

module SolidusCicerone
  class Lookup
    Result = Struct.new(
      :user_id,
      :fallback,
      :generated_at,
      :experiment_id,
      :variant,
      :items,
      keyword_init: true
    )

    Item = Struct.new(
      :item_id,
      :rank,
      :score,
      :source,
      :reasons,
      :variant,
      keyword_init: true
    )

    def self.call(...)
      new(...).call
    end

    def initialize(user: nil, limit: nil, category: nil, exclude_unavailable: true, track: true,
      client: nil, cache: nil, stock_scope: nil)
      @user = user
      @limit = limit
      @category = category
      @exclude_unavailable = exclude_unavailable
      @track = track
      @client = client
      @cache = cache
      @stock_scope = stock_scope
    end

    def call
      return empty_result unless SolidusCicerone.enabled?

      body = fetch
      items = filter_live_stock(Array(body["items"]))
      result = Result.new(
        user_id: body["user_id"] || user_id,
        fallback: body["fallback"] == true || user_id == Ids::COLD_START,
        generated_at: body["generated_at"],
        experiment_id: body["experiment_id"],
        variant: body["variant"],
        items: items
      )
      enqueue_impressions(result) if @track
      result
    rescue Error
      empty_result
    end

    private

    def user_id
      @user_id ||= Ids.lookup_user_id(@user)
    end

    def fetch
      cached { client.recommendations(user_id, **query) }
    end

    def query
      opts = {exclude_unavailable: @exclude_unavailable}
      opts[:limit] = @limit || SolidusCicerone.configuration.default_limit
      opts[:category] = @category unless @category.nil? || @category.to_s.empty?
      opts
    end

    def cached
      store = @cache || (defined?(Rails) && Rails.respond_to?(:cache) ? Rails.cache : nil)
      return yield unless store

      key = ["solidus_cicerone", "recs", user_id, query[:limit], query[:category], @exclude_unavailable]
      store.fetch(key, expires_in: cache_ttl) { yield }
    end

    def cache_ttl
      ttl = SolidusCicerone.configuration.cache_ttl.to_i
      ttl.positive? ? ttl : 45
    end

    def filter_live_stock(items)
      variants = variants_by_id(items.map { |row| row["item_id"] })
      kept = []
      items.each do |row|
        variant = variants[row["item_id"].to_s]
        next if variant && !in_stock?(variant)
        next if variant.nil? && stock_scope?

        kept << Item.new(
          item_id: row["item_id"].to_s,
          rank: row["rank"],
          score: row["score"],
          source: row["source"],
          reasons: row["reasons"],
          variant: variant
        )
      end
      kept
    end

    def variants_by_id(ids)
      scope = @stock_scope
      scope ||= default_stock_scope
      return {} if scope.nil?

      records = scope.respond_to?(:call) ? scope.call(ids) : scope
      Array(records).each_with_object({}) do |variant, memo|
        memo[Ids.item_id_for(variant)] = variant
      end
    end

    def default_stock_scope
      return unless defined?(Spree::Variant)

      ->(ids) { Spree::Variant.where(id: ids) }
    end

    def stock_scope?
      !@stock_scope.nil? || defined?(Spree::Variant)
    end

    def in_stock?(variant)
      return true unless variant.respond_to?(:in_stock?)

      variant.in_stock?
    end

    def enqueue_impressions(result)
      return if result.items.empty?
      return unless defined?(SolidusCicerone::PostTrackJob)

      events = result.items.map do |item|
        EventPayload.track(
          kind: "impression",
          user_id: result.user_id,
          item_id: item.item_id,
          rank: item.rank,
          experiment_id: result.experiment_id,
          variant: result.variant,
          generated_at: result.generated_at
        )
      end
      SolidusCicerone::PostTrackJob.perform_later(events)
    end

    def client
      @client ||= Client.from_config
    end

    def empty_result
      Result.new(user_id: user_id, fallback: true, items: [])
    end
  end
end
