# frozen_string_literal: true

module SolidusCicerone
  module Ids
    COLD_START = ::Cicerone::COLD_START_USER_ID

    module_function

    def user_id_for(record)
      return if record.nil?

      raw = if record.respond_to?(:user_id) && !record.is_a?(String)
              record.user_id
            elsif record.respond_to?(:id)
              record.id
            else
              record
            end
      return if raw.nil? || raw.to_s.empty?

      raw.to_s
    end

    def item_id_for(variant_or_id)
      return if variant_or_id.nil?

      raw = variant_or_id.respond_to?(:id) ? variant_or_id.id : variant_or_id
      return if raw.nil? || raw.to_s.empty?

      raw.to_s
    end

    def guest?(order)
      user_id_for(order).nil?
    end

    def lookup_user_id(user)
      user_id_for(user) || COLD_START
    end

    def event_id(order, line_item)
      "#{order.number}:#{line_item.id}"
    end
  end
end
