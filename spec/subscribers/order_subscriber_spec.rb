# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidusCicerone::OrderSubscriber do
  def publish(order)
    event = Struct.new(:payload).new({order: order})
    described_class.new.on_order_finalized(event)
  end

  it "enqueues PostEventsJob for signed-in finalized orders" do
    publish(SolidusCicerone::SpecFixtures::Order.new(id: 77, user_id: 12))

    expect(SolidusCicerone::PostEventsJob.enqueued).to eq([[77]])
  end

  it "drops guest checkouts" do
    publish(SolidusCicerone::SpecFixtures::Order.new(id: 78, user_id: nil))

    expect(SolidusCicerone::PostEventsJob.enqueued).to eq([])
  end

  it "subscribes to a bus without HTTP" do
    seen = []
    bus = Object.new
    bus.define_singleton_method(:subscribe) do |name, &block|
      seen << name
      block.call(Struct.new(:payload).new({order: SolidusCicerone::SpecFixtures::Order.new(id: 1, user_id: 2)}))
    end

    described_class.new.subscribe_to(bus)

    expect(seen).to eq([:order_finalized])
    expect(SolidusCicerone::PostEventsJob.enqueued).to eq([[1]])
  end
end
