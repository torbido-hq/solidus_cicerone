# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidusCicerone::EventStore do
  it "defaults to Null when ActiveRecord export tables are not loaded" do
    described_class.reset!

    expect(described_class.backend).to be_a(described_class::Null)
    expect(described_class.active_record_available?).to be(false)
  end

  it "does not replace a Memory backend when ensuring ActiveRecord" do
    described_class.ensure_active_record!

    expect(described_class.backend).to be_a(described_class::Memory)
  end

  it "upserts by event_id" do
    described_class.upsert_event(
      "user_id" => "1",
      "item_id" => "9",
      "event_type" => "purchase",
      "quantity" => 1,
      "occurred_at" => "2026-09-17T12:00:00Z",
      "event_id" => "R1:1"
    )
    described_class.upsert_event(
      "user_id" => "1",
      "item_id" => "9",
      "event_type" => "purchase",
      "quantity" => 3,
      "occurred_at" => "2026-09-17T12:00:00Z",
      "event_id" => "R1:1"
    )

    expect(described_class.backend.events.size).to eq(1)
    expect(described_class.backend.events["R1:1"]["quantity"]).to eq(3)
  end

  it "resets to a Null backend" do
    described_class.reset!

    expect(described_class.backend).to be_a(described_class::Null)
    expect(described_class.backend.upsert_event("event_id" => "x")).to be_nil
    expect(described_class.backend.replace_all(users: [], items: [], events: [])).to be_nil
  end

  it "parses loose timestamps and invalid quantities" do
    described_class.backend = described_class::Memory.new
    described_class.upsert_event(
      user_id: "1", item_id: "2", event_type: "view",
      occurred_at: "2026-09-17 12:00:00 UTC", quantity: "nope", event_id: "loose"
    )
    described_class.upsert_event(
      "user_id" => "1", "item_id" => "2", "event_type" => "view",
      "occurred_at" => "not-a-time", "quantity" => -2, "event_id" => "invalid"
    )

    expect(described_class.backend.events.size).to eq(2)
    expect(described_class.backend.events.values.map { |row| row["quantity"] }).to all(eq(1))
  end

  it "writes through ActiveRecord models when they are loaded" do
    calls = []
    model = Class.new do
      define_singleton_method(:upsert) { |attrs, **| calls << [:upsert, attrs] }
      define_singleton_method(:transaction) { |&block| block.call }
      define_singleton_method(:where) { |_| self }
      define_singleton_method(:delete_all) { calls << :delete_all }
      define_singleton_method(:insert_all) { |rows| calls << [:insert_all, rows] }
    end
    stub_const("SolidusCicerone::Event", model)
    stub_const("SolidusCicerone::ExportedUser", model)
    stub_const("SolidusCicerone::ExportedItem", model)

    backend = described_class::ActiveRecordBackend.new
    backend.upsert_event("event_id" => "a", "user_id" => "1")
    backend.replace_all(
      users: [{ "user_id" => "1" }],
      items: [{ "item_id" => "9" }],
      events: []
    )

    expect(calls).to include(:delete_all)
    expect(calls.any? { |call| call.is_a?(Array) && call.first == :upsert }).to be(true)
    expect(calls.count { |call| call.is_a?(Array) && call.first == :insert_all }).to eq(2)
  end
end
