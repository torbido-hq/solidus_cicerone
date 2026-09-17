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
      allowed = attrs.to_h.each_with_object({}) do |(key, value), memo|
        name = key.to_sym
        next unless Configuration::KEYS.include?(name)

        memo[name] = value
      end
      SolidusCicerone.configuration.assign(allowed)
      allowed.each_key do |key|
        preference_set(key, SolidusCicerone.configuration.public_send(key))
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
