# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidusCicerone::EventStore do
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
