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

  it "installs the after_create_commit hook on LineItem" do
    klass = Class.new do
      class << self
        attr_reader :hook
      end

      def self.after_create_commit(method_name)
        @hook = method_name
      end

      def id
        3
      end

      def variant
        SolidusCicerone::SpecFixtures::Variant.new(id: 8)
      end

      def order
        SolidusCicerone::SpecFixtures::Order.new(user_id: 5)
      end

      def quantity
        1
      end
    end
    stub_const("Spree::LineItem", klass)

    described_class.install
    klass.new.solidus_cicerone_record_cart_add

    expect(klass.hook).to eq(:solidus_cicerone_record_cart_add)
    expect(SolidusCicerone::EventStore.backend.events).to have_key("cart_add:3")
  end
end
