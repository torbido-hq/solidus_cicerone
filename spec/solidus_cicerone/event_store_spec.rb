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
end
