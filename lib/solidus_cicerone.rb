# frozen_string_literal: true

require "solidus_cicerone/version"
require "solidus_cicerone/errors"
require "solidus_cicerone/configuration"
require "solidus_cicerone/ids"
require "solidus_cicerone/event_payload"
require "solidus_cicerone/catalog"
require "solidus_cicerone/input"
require "solidus_cicerone/event_store"
require "solidus_cicerone/exporter"
require "solidus_cicerone/client"
require "solidus_cicerone/settings"
require "solidus_cicerone/lookup"

require "solidus_cicerone/engine" if defined?(Rails::Engine)

module SolidusCicerone
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end

    def reset_configuration!
      @configuration = Configuration.new
    end

    def enabled?
      configuration.enabled?
    end

    def serve_url
      Settings.get(:serve_url)
    end

    def serve_token
      Settings.get(:serve_token)
    end

    def events_token
      token = Settings.get(:events_token)
      token.nil? || token.to_s.empty? ? serve_token : token
    end

    def trigger_url
      Settings.get(:trigger_url)
    end

    def trigger_token
      Settings.get(:trigger_token)
    end

    def dashboard_url
      Settings.get(:dashboard_url)
    end

    def client
      Client.new(
        base_url: serve_url,
        token: serve_token,
        events_token: events_token,
        trigger_url: trigger_url,
        trigger_token: trigger_token
      )
    end

    def recommendations_for(user, **opts)
      Lookup.call(user: user, **opts)
    end

    def record_event(payload)
      rows = payload.is_a?(Array) ? payload.compact : [payload].compact
      return if rows.empty?

      rows.each { |row| EventStore.upsert_event(row) }
      enqueue_http_events(rows)
      rows
    end

    def record_interaction(...)
      record_event(EventPayload.interaction(...))
    end

    def record_cart_add(line_item)
      order = line_item.respond_to?(:order) ? line_item.order : nil
      return if order && Ids.guest?(order)

      user = order.respond_to?(:user) && order.user ? order.user : order
      item = line_item.respond_to?(:variant) ? line_item.variant : line_item
      record_event(
        EventPayload.interaction(
          user: user || line_item,
          item: item,
          event_type: "cart_add",
          quantity: line_item.respond_to?(:quantity) ? line_item.quantity : 1,
          event_id: "cart_add:#{line_item.id}"
        )
      )
    end

    def record_view(user, item)
      record_interaction(user: user, item: item, event_type: "view")
    end

    def enqueue_purchases(order)
      record_event(EventPayload.purchases_from_order(order))
    end

    def enqueue_http_events(events)
      return unless defined?(PostEventsJob)

      PostEventsJob.perform_later(Array(events))
    end

    def enqueue_track(events)
      return unless defined?(PostTrackJob)

      PostTrackJob.perform_later(Array(events))
    end

    def enqueue_impressions(result)
      return if result.nil?

      items = result.respond_to?(:items) ? result.items : []
      return if items.empty?

      events = items.map do |item|
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
      enqueue_track(events)
    end

    def enqueue_export
      return unless defined?(ExportJob)

      ExportJob.perform_later
    end

    def enqueue_retrain
      return unless defined?(RetrainJob)

      RetrainJob.perform_later
    end
  end
end
