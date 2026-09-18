# frozen_string_literal: true

require "time"

require "solidus_cicerone/event_payload"

module SolidusCicerone
  module EventStore
    REBUILD_EVENT_TYPES = %w[purchase review_positive review_negative saved].freeze

    module_function

    def backend
      @backend ||= Null.new
    end

    def backend=(value)
      @backend = value
    end

    def reset!
      @backend = nil
    end

    def upsert_event(row)
      attrs = normalize_event(row)
      return if attrs.nil?

      backend.upsert_event(attrs)
      attrs
    end

    def replace_all(users:, items:, events:)
      backend.replace_all(
        users: Array(users).map { |row| normalize_user(row) }.compact,
        items: Array(items).map { |row| normalize_item(row) }.compact,
        events: Array(events).map { |row| normalize_event(row) }.compact
      )
    end

    def normalize_event(row)
      return if row.nil?

      user_id = row["user_id"] || row[:user_id]
      item_id = row["item_id"] || row[:item_id]
      event_type = row["event_type"] || row[:event_type]
      return if user_id.nil? || item_id.nil? || event_type.nil?

      occurred_at = parse_time(row["occurred_at"] || row[:occurred_at])
      event_id = row["event_id"] || row[:event_id]
      event_id = "#{event_type}:#{user_id}:#{item_id}:#{occurred_at}" if event_id.nil? || event_id.to_s.empty?

      {
        "user_id" => user_id.to_s,
        "item_id" => item_id.to_s,
        "event_type" => event_type.to_s,
        "quantity" => quantity(row["quantity"] || row[:quantity]),
        "occurred_at" => occurred_at,
        "event_id" => event_id.to_s
      }
    end

    def normalize_user(row)
      return if row.nil?

      user_id = row["user_id"] || row[:user_id]
      return if user_id.nil? || user_id.to_s.empty?

      {
        "user_id" => user_id.to_s,
        "country" => blank_to_nil(row["country"] || row[:country])
      }
    end

    def normalize_item(row)
      return if row.nil?

      item_id = row["item_id"] || row[:item_id]
      return if item_id.nil? || item_id.to_s.empty?

      {
        "item_id" => item_id.to_s,
        "category" => (row["category"] || row[:category]).to_s,
        "published" => row["published"] || row[:published] == true,
        "in_stock" => row["in_stock"] || row[:in_stock] == true
      }
    end

    def parse_time(value)
      return EventPayload.now_utc if value.nil?
      return value.utc if value.respond_to?(:utc)
      return Time.iso8601(value.to_s).utc if value.is_a?(String) && value.include?("T")

      Time.parse(value.to_s).utc
    rescue ArgumentError
      EventPayload.now_utc
    end

    def quantity(value)
      qty = Integer(value || 1)
      qty.positive? ? qty : 1
    rescue ArgumentError, TypeError
      1
    end

    def blank_to_nil(value)
      value.nil? || value.to_s.empty? ? nil : value.to_s
    end

    class Memory
      attr_reader :events, :users, :items

      def initialize
        @events = {}
        @users = {}
        @items = {}
      end

      def upsert_event(row)
        @events[row.fetch("event_id")] = row
      end

      def replace_all(users:, items:, events:)
        @users = users.to_h { |row| [row.fetch("user_id"), row] }
        @items = items.to_h { |row| [row.fetch("item_id"), row] }
        kept = @events.reject { |_id, row| EventStore::REBUILD_EVENT_TYPES.include?(row["event_type"]) }
        rebuilt = events.to_h { |row| [row.fetch("event_id"), row] }
        @events = kept.merge(rebuilt)
      end
    end

    class Null
      def upsert_event(_row)
        nil
      end

      def replace_all(**)
        nil
      end
    end

    class ActiveRecordBackend
      def upsert_event(row)
        attrs = timestamped(row)
        ::SolidusCicerone::Event.upsert(attrs, unique_by: :event_id)
      end

      def replace_all(users:, items:, events:)
        ::SolidusCicerone::Event.transaction do
          ::SolidusCicerone::ExportedUser.delete_all
          ::SolidusCicerone::ExportedItem.delete_all
          ::SolidusCicerone::Event.where(event_type: REBUILD_EVENT_TYPES).delete_all
          insert_all(::SolidusCicerone::ExportedUser, users)
          insert_all(::SolidusCicerone::ExportedItem, items)
          insert_all(::SolidusCicerone::Event, events)
        end
      end

      private

      def insert_all(model, rows)
        return if rows.empty?

        now = EventPayload.now_utc
        model.insert_all(rows.map { |row| timestamped(row, now) })
      end

      def timestamped(row, now = EventPayload.now_utc)
        row.merge("created_at" => now, "updated_at" => now)
      end
    end
  end
end
