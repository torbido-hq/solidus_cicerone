# frozen_string_literal: true

module SolidusCicerone
  class OrderSubscriber
    include Omnes::Subscriber if defined?(Omnes::Subscriber)

    handle :order_finalized, with: :on_order_finalized if respond_to?(:handle)

    def subscribe_to(bus)
      if defined?(Omnes::Subscriber) && is_a?(Omnes::Subscriber)
        super
      elsif bus.respond_to?(:subscribe)
        bus.subscribe(:order_finalized) { |event| on_order_finalized(event) }
      end
      self
    end

    def on_order_finalized(event)
      order = order_from(event)
      SolidusCicerone.enqueue_purchases(order)
    end

    private

    def order_from(event)
      if event.respond_to?(:payload)
        event.payload[:order] || event.payload["order"]
      elsif event.respond_to?(:[])
        event[:order] || event["order"]
      end
    end
  end
end
