# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidusCicerone::OrderSubscriber do
  def order(id:, user_id:, number: "R1")
    SolidusCicerone::SpecFixtures::Order.new(
      id: id,
      number: number,
      user_id: user_id,
      completed_at: Time.utc(2026, 9, 17, 12, 0, 0),
      line_items: [
        SolidusCicerone::SpecFixtures::LineItem.new(
          id: 44,
          variant: SolidusCicerone::SpecFixtures::Variant.new(id: 99),
          quantity: 1
        )
      ]
    )
  end

  def publish(record)
    event = Struct.new(:payload).new({ order: record })
    described_class.new.on_order_finalized(event)
  end

  it "records purchases and enqueues PostEventsJob for signed-in finalized orders" do
    publish(order(id: 77, user_id: 12, number: "R77"))

    expect(SolidusCicerone::EventStore.backend.events.keys).to eq(["R77:44"])
    expect(SolidusCicerone::PostEventsJob.enqueued.first.first).to contain_exactly(
      hash_including("event_type" => "purchase", "event_id" => "R77:44")
    )
  end

  it "reads an order from a hash-like event" do
    record = order(id: 80, user_id: 4, number: "R80")

    described_class.new.on_order_finalized({ order: record })

    expect(SolidusCicerone::EventStore.backend.events.keys).to eq(["R80:44"])
  end

  it "drops guest checkouts" do
    publish(order(id: 78, user_id: nil))

    expect(SolidusCicerone::PostEventsJob.enqueued).to eq([])
    expect(SolidusCicerone::EventStore.backend.events).to eq({})
  end

  it "subscribes to a bus without HTTP" do
    seen = []
    record = order(id: 1, user_id: 2)
    bus = Object.new
    bus.define_singleton_method(:subscribe) do |name, &block|
      seen << name
      block.call(Struct.new(:payload).new({ order: record }))
    end

    described_class.new.subscribe_to(bus)

    expect(seen).to eq([:order_finalized])
    expect(SolidusCicerone::PostEventsJob.enqueued.size).to eq(1)
  end
end
