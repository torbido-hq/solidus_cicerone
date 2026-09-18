# frozen_string_literal: true

require "solidus_cicerone/catalog"
require "solidus_cicerone/event_payload"
require "solidus_cicerone/event_store"
require "solidus_cicerone/ids"

module SolidusCicerone
  class Exporter
    def self.call(...)
      new(...).call
    end

    def initialize(orders: nil, users: nil, variants: nil, reviews: nil, wished_items: nil)
      @orders = orders
      @users = users
      @variants = variants
      @reviews = reviews
      @wished_items = wished_items
      @injected = {
        orders: !orders.nil?,
        users: !users.nil?,
        variants: !variants.nil?,
        reviews: !reviews.nil?,
        wished_items: !wished_items.nil?
      }
    end

    def call
      EventStore.replace_all(users: user_rows, items: item_rows, events: event_rows)
    end

    private

    def user_rows
      rows = []
      each_record(users) do |user|
        next unless Ids.user_id_for(user)

        rows << Catalog.user_row(user)
      end
      rows
    end

    def item_rows
      seen = {}
      rows = []
      each_record(variants) do |variant|
        row = Catalog.item_row(variant)
        next if row["item_id"].nil? || seen[row["item_id"]]

        seen[row["item_id"]] = true
        rows << row
      end
      rows
    end

    def event_rows
      purchases + review_events + wishlist_events
    end

    def purchases
      rows = []
      each_record(orders) { |order| rows.concat(EventPayload.purchases_from_order(order)) }
      rows
    end

    def review_events
      rows = []
      each_record(reviews) do |review|
        event = Catalog.review_event(review)
        rows << event if event
      end
      rows
    end

    def wishlist_events
      rows = []
      each_record(wished_items) do |item|
        event = Catalog.wishlist_event(item)
        rows << event if event
      end
      rows
    end

    def each_record(scope, &block)
      if scope.respond_to?(:find_each)
        scope.find_each(&block)
      else
        Array(scope).each(&block)
      end
    end

    def orders
      return @orders if @injected[:orders]

      scope = Spree::Order.complete.where.not(user_id: nil)
      scope = scope.where(canceled_at: nil) if order_canceled_at?
      scope.includes(line_items: :variant)
    end

    def users
      return @users if @injected[:users]

      Spree::User.all
    end

    def variants
      return @variants if @injected[:variants]

      scope = Spree::Variant
      scope = scope.not_deleted if scope.respond_to?(:not_deleted)
      scope.includes(:product, product: :taxons)
    end

    def reviews
      return @reviews if @injected[:reviews]

      klass = extension_class(:Review)
      klass ? klass.all : []
    end

    def wished_items
      return @wished_items if @injected[:wished_items]

      klass = extension_class(:WishedItem) || extension_class(:WishlistItem)
      klass ? klass.all : []
    end

    def order_canceled_at?
      Spree::Order.column_names.include?("canceled_at")
    end

    def extension_class(name)
      return Spree.const_get(name) if Spree.const_defined?(name, false)

      nil
    end
  end
end
