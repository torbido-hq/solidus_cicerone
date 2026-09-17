# frozen_string_literal: true

module SolidusCicerone
  class PostEventsJob < ApplicationJob
    def perform(order_id, events = nil)
      return unless SolidusCicerone.enabled?

      payload = events.nil? || Array(events).empty? ? purchases_for(order_id) : Array(events)
      return if payload.empty?

      SolidusCicerone.client.post_events(payload)
    end

    private

    def purchases_for(order_id)
      order = find_order(order_id)
      return [] if order.nil? || Ids.guest?(order)

      EventPayload.purchases_from_order(order)
    end

    def find_order(order_id)
      return order_id if order_id.respond_to?(:line_items)
      return unless defined?(Spree::Order)

      Spree::Order.find_by(id: order_id)
    end
  end
end
