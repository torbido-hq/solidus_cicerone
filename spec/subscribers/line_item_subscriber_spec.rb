# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidusCicerone::LineItemSubscriber do
  it "records cart_add for a signed-in line item" do
    variant = SolidusCicerone::SpecFixtures::Variant.new(id: 8)
    order = SolidusCicerone::SpecFixtures::Order.new(id: 1, number: "R1", user_id: 5)
    line = SolidusCicerone::SpecFixtures::LineItem.new(id: 3, variant: variant, quantity: 2, order: order)

    described_class.on_create(line)

    expect(SolidusCicerone::EventStore.backend.events.fetch("cart_add:3")).to include(
      "event_type" => "cart_add",
      "user_id" => "5",
      "item_id" => "8",
      "quantity" => 2
    )
    expect(SolidusCicerone::PostEventsJob.enqueued.size).to eq(1)
  end

  it "drops guest cart adds" do
    order = SolidusCicerone::SpecFixtures::Order.new(id: 1, user_id: nil)
    line = SolidusCicerone::SpecFixtures::LineItem.new(
      id: 3,
      variant: SolidusCicerone::SpecFixtures::Variant.new(id: 8),
      quantity: 1,
      order: order
    )

    described_class.on_create(line)

    expect(SolidusCicerone::EventStore.backend.events).to eq({})
    expect(SolidusCicerone::PostEventsJob.enqueued).to eq([])
  end
end
