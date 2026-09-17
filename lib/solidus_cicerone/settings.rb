# frozen_string_literal: true

module SolidusCicerone
  module Settings
    PREFIX = "solidus_cicerone/"

    module_function

    def get(key)
      stored = preference_get(key)
      return stored unless stored.nil? || stored.to_s.empty?

      SolidusCicerone.configuration.public_send(key)
    end

    def set(attrs)
      attrs.each do |key, value|
        next unless Configuration::KEYS.include?(key.to_sym)

        preference_set(key, value)
        SolidusCicerone.configuration.public_send("#{key}=", value)
      end
    end

    def preference_get(key)
      store = preference_store
      return unless store

      store.get("#{PREFIX}#{key}")
    rescue StandardError
      nil
    end

    def preference_set(key, value)
      store = preference_store
      return unless store

      store.set("#{PREFIX}#{key}", value)
    rescue StandardError
      nil
    end

    def preference_store
      return unless defined?(Spree::Preferences::Store)

      Spree::Preferences::Store.instance
    end
  end
end
