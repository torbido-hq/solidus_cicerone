# frozen_string_literal: true

require "solidus_cicerone/version"
require "solidus_cicerone/errors"
require "solidus_cicerone/configuration"
require "solidus_cicerone/ids"
require "solidus_cicerone/event_payload"
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

    def enqueue_purchases(order)
      return if Ids.guest?(order)
      return unless defined?(PostEventsJob)

      PostEventsJob.perform_later(order.id)
    end

    def enqueue_track(events)
      return unless defined?(PostTrackJob)

      PostTrackJob.perform_later(Array(events))
    end

    def enqueue_retrain
      return unless defined?(RetrainJob)

      RetrainJob.perform_later
    end
  end
end
