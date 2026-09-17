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

    attr_accessor(*KEYS)

    def initialize
      @serve_url = ENV["CICERONE_SERVE_URL"]
      @serve_token = ENV["CICERONE_SERVE_TOKEN"]
      @events_token = ENV["CICERONE_EVENTS_TOKEN"]
      @trigger_url = ENV["CICERONE_TRIGGER_URL"]
      @trigger_token = ENV["CICERONE_TRIGGER_TOKEN"]
      @dashboard_url = ENV["CICERONE_DASHBOARD_URL"]
      @cache_ttl = integer_env("CICERONE_CACHE_TTL", 45)
      @default_limit = integer_env("CICERONE_DEFAULT_LIMIT", 10)
      @enabled = ENV["CICERONE_ENABLED"] != "false"
    end

    def enabled?
      @enabled != false
    end

    def assign(attrs)
      attrs.each do |key, value|
        writer = "#{key}="
        public_send(writer, coerce(key.to_sym, value)) if respond_to?(writer)
      end
      self
    end

    def to_h
      KEYS.each_with_object({}) { |key, memo| memo[key] = public_send(key) }
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
      raw = ENV[name]
      raw.nil? || raw.empty? ? default : Integer(raw)
    end
  end
end
