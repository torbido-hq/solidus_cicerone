# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidusCicerone::Exporter do
  let(:product) do
    SolidusCicerone::SpecFixtures::Product.new(
      slug: "lager",
      taxons: [
        SolidusCicerone::SpecFixtures::Taxon.new(id: 1, name: "Beer", lft: 1),
        SolidusCicerone::SpecFixtures::Taxon.new(id: 2, name: "Seasonal", lft: 4)
      ]
    )
  end
  let(:variant) { SolidusCicerone::SpecFixtures::Variant.new(id: 99, stock: true, product: product) }
  let(:user) { SolidusCicerone::SpecFixtures::User.new(12) }
  let(:order) do
    SolidusCicerone::SpecFixtures::Order.new(
      id: 7,
      number: "R123",
      user_id: 12,
      completed_at: Time.utc(2026, 9, 17, 12, 0, 0),
      line_items: [
        SolidusCicerone::SpecFixtures::LineItem.new(id: 44, variant: variant, quantity: 2)
      ]
    )
  end

  it "writes unique items and purchase events" do
    described_class.call(orders: [order], users: [user], variants: [variant], reviews: [], wished_items: [])

    store = SolidusCicerone::EventStore.backend
    expect(store.items.keys).to eq(["99"])
    expect(store.items["99"]["category"]).to eq("Beer")
    expect(store.users.keys).to eq(["12"])
    expect(store.events.keys).to eq(["R123:44"])
  end

  it "keeps live cart_add rows when purchases are rebuilt" do
    SolidusCicerone.record_cart_add(
      SolidusCicerone::SpecFixtures::LineItem.new(
        id: 3,
        variant: variant,
        quantity: 1,
        order: SolidusCicerone::SpecFixtures::Order.new(user_id: 12)
      )
    )

    described_class.call(orders: [order], users: [user], variants: [variant], reviews: [], wished_items: [])

    expect(SolidusCicerone::EventStore.backend.events.keys).to contain_exactly("cart_add:3", "R123:44")
  end

  it "drops guest orders from the export" do
    guest = SolidusCicerone::SpecFixtures::Order.new(
      id: 8,
      number: "R9",
      user_id: nil,
      completed_at: Time.utc(2026, 9, 17),
      line_items: [SolidusCicerone::SpecFixtures::LineItem.new(id: 1, variant: variant, quantity: 1)]
    )

    described_class.call(orders: [guest], users: [], variants: [variant], reviews: [], wished_items: [])

    expect(SolidusCicerone::EventStore.backend.events).to eq({})
  end

  it "loads catalog from Spree when collections are not injected" do
    chain = Class.new do
      def self.complete
        self
      end

      def self.where(*)
        self
      end

      def self.not(*)
        self
      end

      def self.includes(*)
        []
      end

      def self.column_names
        %w[canceled_at]
      end

      def self.all
        []
      end

      def self.not_deleted
        self
      end
    end
    stub_const("Spree::Order", chain)
    stub_const("Spree::User", chain)
    stub_const("Spree::Variant", chain)
    stub_const("Spree::Review", chain)
    stub_const("Spree::WishedItem", chain)

    described_class.call

    expect(SolidusCicerone::EventStore.backend.users).to eq({})
    expect(SolidusCicerone::EventStore.backend.items).to eq({})
  end
end
