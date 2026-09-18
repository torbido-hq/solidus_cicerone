# frozen_string_literal: true

require "json"

require "solidus_cicerone/ids"

module SolidusCicerone
  module EventPayload
    module_function

    def purchases_from_order(order)
      return [] if Ids.guest?(order)

      user_id = Ids.user_id_for(order)
      occurred_at = iso8601(order.respond_to?(:completed_at) ? order.completed_at : nil)
      line_items_for(order).filter_map do |line_item|
        variant = variant_for(line_item) || (line_item.respond_to?(:variant_id) && line_item.variant_id)
        item_id = Ids.item_id_for(variant)
        next if item_id.nil?

        {
          "user_id" => user_id,
          "item_id" => item_id,
          "event_type" => "purchase",
          "quantity" => quantity_for(line_item),
          "occurred_at" => occurred_at,
          "event_id" => Ids.event_id(order, line_item)
        }
      end
    end

    def interaction(user:, item:, event_type:, occurred_at: nil, quantity: 1, event_id: nil)
      user_id = Ids.user_id_for(user)
      item_id = Ids.item_id_for(item)
      return if user_id.nil? || item_id.nil?

      payload = {
        "user_id" => user_id,
        "item_id" => item_id,
        "event_type" => event_type.to_s,
        "quantity" => Integer(quantity),
        "occurred_at" => iso8601(occurred_at)
      }
      payload["event_id"] = event_id.to_s unless event_id.nil? || event_id.to_s.empty?
      payload
    end

    def track(kind:, user_id:, item_id:, occurred_at: nil, rank: nil, experiment_id: nil, variant: nil,
              generated_at: nil, event_id: nil)
      occurred = iso8601(occurred_at)
      payload = {
        "kind" => kind.to_s,
        "user_id" => user_id.to_s,
        "item_id" => item_id.to_s,
        "occurred_at" => occurred
      }
      payload["rank"] = Integer(rank) unless rank.nil? || rank.to_s.empty?
      payload["experiment_id"] = experiment_id unless experiment_id.nil? || experiment_id.to_s.empty?
      payload["variant"] = variant unless variant.nil? || variant.to_s.empty?
      payload["generated_at"] = generated_at unless generated_at.nil? || generated_at.to_s.empty?
      id = track_event_id(
        event_id: event_id,
        kind: payload["kind"],
        user_id: payload["user_id"],
        item_id: payload["item_id"],
        generated_at: payload["generated_at"],
        rank: payload["rank"]
      )
      payload["event_id"] = id unless id.nil? || id.to_s.empty?
      payload
    end

    def track_event_id(event_id:, kind:, user_id:, item_id:, generated_at:, rank:)
      return event_id.to_s unless event_id.nil? || event_id.to_s.empty?
      return if generated_at.nil? || generated_at.to_s.empty?

      JSON.generate([kind, user_id, item_id, generated_at, rank])
    end

    def iso8601(time)
      stamp = time.nil? ? now_utc : time
      stamp = stamp.utc if stamp.respond_to?(:utc)
      stamp.respond_to?(:iso8601) ? stamp.iso8601 : stamp.to_s
    end

    def now_utc
      if defined?(Time.zone) && Time.zone
        Time.zone.now.utc
      else
        Time.now.utc
      end
    end

    def line_items_for(order)
      return [] unless order.respond_to?(:line_items)

      items = order.line_items
      items.respond_to?(:to_a) ? items.to_a : Array(items)
    end

    def variant_for(line_item)
      return unless line_item.respond_to?(:variant)

      line_item.variant
    end

    def quantity_for(line_item)
      raw = line_item.respond_to?(:quantity) ? line_item.quantity : 1
      qty = Integer(raw)
      qty.positive? ? qty : 1
    rescue ArgumentError, TypeError
      1
    end
  end
end
