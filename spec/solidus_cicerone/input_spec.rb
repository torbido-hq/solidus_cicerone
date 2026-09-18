# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidusCicerone::Input do
  it "authors portable SELECTs against the export tables" do
    expect(described_class.events).to eq(
      "SELECT user_id, item_id, event_type, quantity, occurred_at FROM solidus_cicerone_events"
    )
    expect(described_class.users).to eq("SELECT user_id, country FROM solidus_cicerone_users")
    expect(described_class.items).to eq(
      "SELECT item_id, category, published, in_stock FROM solidus_cicerone_items"
    )
  end

  it "compiles an ActiveRecord relation via unprepared to_sql" do
    connection = Object.new
    def connection.unprepared_statement
      yield.sub("$1", "'2024-01-01'")
    end
    relation = Object.new
    relation.define_singleton_method(:connection) { connection }
    def relation.to_sql
      'SELECT "user_id" FROM "solidus_cicerone_events" WHERE occurred_at >= $1;'
    end

    expect(described_class.events(relation)).to eq(
      "SELECT \"user_id\" FROM \"solidus_cicerone_events\" WHERE occurred_at >= '2024-01-01'"
    )
  end

  it "accepts a SQL string and uses the model cicerone_input relation when present" do
    expect(described_class.users("SELECT user_id FROM solidus_cicerone_users ;")).to eq(
      "SELECT user_id FROM solidus_cicerone_users"
    )
    expect(described_class.items(Object.new)).to eq(
      "SELECT item_id, category, published, in_stock FROM solidus_cicerone_items"
    )

    model = Class.new do
      def self.cicerone_input
        relation = Object.new
        def relation.to_sql
          "SELECT user_id FROM solidus_cicerone_users WHERE country IS NOT NULL"
        end
        relation
      end
    end
    stub_const("SolidusCicerone::ExportedUser", model)
    stub_const("SolidusCicerone::Event", Class.new)

    expect(described_class.users).to eq("SELECT user_id FROM solidus_cicerone_users WHERE country IS NOT NULL")
    expect(described_class.events).to eq(
      "SELECT user_id, item_id, event_type, quantity, occurred_at FROM solidus_cicerone_events"
    )
  end

  it "renders a paste-ready [input] fragment and escapes TOML quotes" do
    fragment = described_class.toml_fragment(
      database_url: "${SOLIDUS_DATABASE_URL}",
      events: 'SELECT "user_id" FROM solidus_cicerone_events'
    )

    expect(fragment).to include("kind = \"db\"")
    expect(fragment).to include("database_url = \"${SOLIDUS_DATABASE_URL}\"")
    expect(fragment).to include('events_query = "SELECT \\"user_id\\" FROM solidus_cicerone_events"')
    expect(fragment).to include("users_query = \"SELECT user_id, country FROM solidus_cicerone_users\"")
    expect(fragment).to include(
      "items_query = \"SELECT item_id, category, published, in_stock FROM solidus_cicerone_items\""
    )
    expect(described_class.queries.keys).to eq(%i[events_query users_query items_query])
    expect(described_class.toml_basic_string("a\\b\"c\n\t")).to eq('"a\\\\b\\"c\\n\\t"')
    expect(described_class.toml_fragment(events: "SELECT 1\nFROM dual")).to include(
      'events_query = "SELECT 1\\nFROM dual"'
    )
    expect(described_class.toml_basic_string("\u0001")).to eq('"\\u0001"')
  end
end
