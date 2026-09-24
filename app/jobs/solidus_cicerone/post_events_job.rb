# frozen_string_literal: true

module SolidusCicerone
  class PostEventsJob < ApplicationJob
    def perform(order_or_events = nil, events = nil)
      return unless SolidusCicerone.enabled?

      payload = resolve_payload(order_or_events, events)
      return if payload.empty?

      SolidusCicerone.client.record(payload)
    end

    private

    def resolve_payload(order_or_events, events)
      return Array(events) unless events.nil? || Array(events).empty?
      return Array(order_or_events) if order_or_events.is_a?(Array)

      purchases_for(order_or_events)
    end

    def purchases_for(order_id)
      order = find_order(order_id)
      return [] if order.nil? || Ids.guest?(order)

      EventPayload.purchases_from_order(order)
    end

    def find_order(order_id)
      return order_id if order_id.respond_to?(:line_items)
      return [] if order_id.nil?

      Spree::Order.find_by(id: order_id)
    end
  end
end
