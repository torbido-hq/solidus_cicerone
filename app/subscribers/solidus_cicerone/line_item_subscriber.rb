# frozen_string_literal: true

module SolidusCicerone
  class LineItemSubscriber
    def self.install
      return if Spree::LineItem.included_modules.include?(LineItemEvents)

      Spree::LineItem.include(LineItemEvents)
    end

    def self.on_create(line_item)
      SolidusCicerone.record_cart_add(line_item)
    end
  end

  module LineItemEvents
    def self.included(base)
      base.after_create_commit(:solidus_cicerone_record_cart_add) if base.respond_to?(:after_create_commit)
    end

    def solidus_cicerone_record_cart_add
      LineItemSubscriber.on_create(self)
    end
  end
end
