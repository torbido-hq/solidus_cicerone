# frozen_string_literal: true

module SolidusCicerone
  class Configuration
    KEYS = %i[
      serve_url
      serve_token
      events_token
      trigger_url
      trigger_token
      dashboard_url
      cache_ttl
      default_limit
      enabled
    ].freeze

    attr_accessor(*KEYS, :faraday)

    def initialize
      @serve_url = ENV.fetch("CICERONE_SERVE_URL", nil)
      @serve_token = ENV.fetch("CICERONE_SERVE_TOKEN", nil)
      @events_token = ENV.fetch("CICERONE_EVENTS_TOKEN", nil)
      @trigger_url = ENV.fetch("CICERONE_TRIGGER_URL", nil)
      @trigger_token = ENV.fetch("CICERONE_TRIGGER_TOKEN", nil)
      @dashboard_url = ENV.fetch("CICERONE_DASHBOARD_URL", nil)
      @cache_ttl = integer_env("CICERONE_CACHE_TTL", 45)
      @default_limit = integer_env("CICERONE_DEFAULT_LIMIT", 10)
      @enabled = ENV["CICERONE_ENABLED"] != "false"
    end

    def enabled?
      value = @enabled
      return false if value == false || value.to_s == "false" || value.to_s == "0" || value.nil?

      true
    end

    def assign(attrs)
      attrs.each do |key, value|
        writer = "#{key}="
        public_send(writer, coerce(key.to_sym, value)) if respond_to?(writer)
      end
      self
    end

    def to_h
      KEYS.to_h { |key| [key, public_send(key)] }
    end

    private

    def coerce(key, value)
      case key
      when :cache_ttl, :default_limit
        value.to_i
      when :enabled
        value == true || value.to_s == "true" || value == "1"
      else
        value.respond_to?(:strip) ? value.strip : value
      end
    end

    def integer_env(name, default)
      raw = ENV.fetch(name, nil)
      raw.nil? || raw.empty? ? default : Integer(raw)
    end
  end
end
