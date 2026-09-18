# frozen_string_literal: true

require "erb"

module SolidusCicerone
  # Author Cicerone `[input] kind=db` SELECTs from ActiveRecord (or ERb that prints SQL).
  # Cicerone never loads Ruby; paste the strings this module emits on the Cicerone deploy.
  module Input
    EVENTS_TABLE = "solidus_cicerone_events"
    USERS_TABLE = "solidus_cicerone_users"
    ITEMS_TABLE = "solidus_cicerone_items"
    EVENT_COLUMNS = %w[user_id item_id event_type quantity occurred_at].freeze
    USER_COLUMNS = %w[user_id country].freeze
    ITEM_COLUMNS = %w[item_id category published in_stock].freeze
    DEFAULT_DATABASE_URL = "${SOLIDUS_DATABASE_URL}"
    TEMPLATE = File.expand_path("templates/input.toml.erb", __dir__)

    module_function

    def events(source = default_relation(:Event))
      sql_from(source, table: EVENTS_TABLE, columns: EVENT_COLUMNS)
    end

    def users(source = default_relation(:ExportedUser))
      sql_from(source, table: USERS_TABLE, columns: USER_COLUMNS)
    end

    def items(source = default_relation(:ExportedItem))
      sql_from(source, table: ITEMS_TABLE, columns: ITEM_COLUMNS)
    end

    def queries(events: default_relation(:Event), users: default_relation(:ExportedUser),
                items: default_relation(:ExportedItem))
      {
        events_query: sql_from(events, table: EVENTS_TABLE, columns: EVENT_COLUMNS),
        users_query: sql_from(users, table: USERS_TABLE, columns: USER_COLUMNS),
        items_query: sql_from(items, table: ITEMS_TABLE, columns: ITEM_COLUMNS)
      }
    end

    def toml_fragment(database_url: DEFAULT_DATABASE_URL, **sources)
      compiled = queries(**sources.slice(:events, :users, :items))
      ERB.new(File.read(TEMPLATE), trim_mode: "-").result_with_hash(
        database_url: toml_basic_string(database_url),
        events_query: toml_basic_string(compiled[:events_query]),
        users_query: toml_basic_string(compiled[:users_query]),
        items_query: toml_basic_string(compiled[:items_query])
      )
    end

    def sql_from(source, table:, columns:)
      return select_sql(table, columns) if source.nil?
      return normalize_sql(source) if source.is_a?(String)
      return normalize_sql(unprepared_sql(source)) if source.respond_to?(:to_sql)

      select_sql(table, columns)
    end

    def default_relation(name)
      return unless SolidusCicerone.const_defined?(name, false)

      model = SolidusCicerone.const_get(name, false)
      return unless model.respond_to?(:cicerone_input)

      model.cicerone_input
    end

    def unprepared_sql(source)
      connection = source.respond_to?(:connection) ? source.connection : nil
      return connection.unprepared_statement { source.to_sql } if connection.respond_to?(:unprepared_statement)

      source.to_sql
    end

    def select_sql(table, columns)
      "SELECT #{columns.join(", ")} FROM #{table}"
    end

    def normalize_sql(sql)
      sql.to_s.strip.sub(/\s*;\s*\z/, "")
    end

    def toml_basic_string(value)
      +'"' << value.to_s.gsub(/[\\"]/) { |char| "\\#{char}" } << '"'
    end
  end
end
