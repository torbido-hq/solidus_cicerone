# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidusCicerone::EventPayload do
  let(:completed_at) { Time.utc(2026, 9, 17, 12, 0, 0) }

  it "builds purchase events per line item with order.number:line_item.id" do
    variant = SolidusCicerone::SpecFixtures::Variant.new(id: 99)
    line = SolidusCicerone::SpecFixtures::LineItem.new(id: 44, variant: variant, quantity: 2)
    order = SolidusCicerone::SpecFixtures::Order.new(
      id: 7, number: "R123", user_id: 12, completed_at: completed_at, line_items: [line]
    )

    expect(described_class.purchases_from_order(order)).to eq(
      [
        {
          "user_id" => "12",
          "item_id" => "99",
          "event_type" => "purchase",
          "quantity" => 2,
          "occurred_at" => "2026-09-17T12:00:00Z",
          "event_id" => "R123:44"
        }
      ]
    )
  end

  it "drops guest orders" do
    line = SolidusCicerone::SpecFixtures::LineItem.new(id: 1, variant: SolidusCicerone::SpecFixtures::Variant.new(id: 2), quantity: 1)
    order = SolidusCicerone::SpecFixtures::Order.new(
      id: 3, number: "R1", user_id: nil, completed_at: completed_at, line_items: [line]
    )

    expect(described_class.purchases_from_order(order)).to eq([])
  end

  it "skips line items without a variant id" do
    line = SolidusCicerone::SpecFixtures::LineItem.new(id: 1, variant: nil, variant_id: nil, quantity: 1)
    order = SolidusCicerone::SpecFixtures::Order.new(
      id: 3, number: "R1", user_id: 4, completed_at: completed_at, line_items: [line]
    )

    expect(described_class.purchases_from_order(order)).to eq([])
  end

  it "builds optional interaction events" do
    payload = described_class.interaction(
      user: SolidusCicerone::SpecFixtures::Order.new(user_id: 5),
      item: SolidusCicerone::SpecFixtures::Variant.new(id: 8),
      event_type: :cart_add,
      quantity: 1,
      occurred_at: completed_at
    )

    expect(payload).to include(
      "user_id" => "5",
      "item_id" => "8",
      "event_type" => "cart_add",
      "quantity" => 1
    )
  end

  it "builds track impression/click payloads" do
    payload = described_class.track(
      kind: :click,
      user_id: "12",
      item_id: "99",
      rank: 1,
      occurred_at: completed_at
    )

    expect(payload).to include(
      "kind" => "click",
      "user_id" => "12",
      "item_id" => "99",
      "rank" => 1,
      "event_id" => "click:12:99:1"
    )
  end

  it "keeps an explicit track event_id" do
    payload = described_class.track(
      kind: :click, user_id: "12", item_id: "99", rank: 1, event_id: "click-1"
    )

    expect(payload["event_id"]).to eq("click-1")
  end

  it "uses generated_at in the default event_id, not occurred_at" do
    payload = described_class.track(
      kind: :click,
      user_id: "12",
      item_id: "99",
      rank: 1,
      occurred_at: completed_at,
      generated_at: "2026-09-17T03:00:00Z"
    )

    expect(payload["event_id"]).to eq("click:12:99:2026-09-17T03:00:00Z:1")
  end

  it "stays stable across retries when generated_at is omitted" do
    allow(described_class).to receive(:now_utc).and_return(
      Time.utc(2026, 1, 1, 0, 0, 0),
      Time.utc(2026, 1, 2, 0, 0, 0)
    )

    first = described_class.track(kind: :click, user_id: "12", item_id: "99", rank: 1)
    second = described_class.track(kind: :click, user_id: "12", item_id: "99", rank: 1)

    expect(first["event_id"]).to eq("click:12:99:1")
    expect(second["event_id"]).to eq(first["event_id"])
    expect(first["occurred_at"]).not_to eq(second["occurred_at"])
  end
end
