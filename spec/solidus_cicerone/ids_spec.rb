# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidusCicerone::Ids do
  it "stringifies user ids" do
    expect(described_class.user_id_for(SolidusCicerone::SpecFixtures::User.new(12))).to eq("12")
  end

  it "reads order.user_id and treats nil as guest" do
    expect(described_class.user_id_for(SolidusCicerone::SpecFixtures::Order.new(user_id: 9))).to eq("9")
    expect(described_class.guest?(SolidusCicerone::SpecFixtures::Order.new(user_id: nil))).to be(true)
    expect(described_class.guest?(SolidusCicerone::SpecFixtures::Order.new(user_id: 1))).to be(false)
  end

  it "uses __cold_start__ when no user is present" do
    expect(described_class.lookup_user_id(nil)).to eq("__cold_start__")
    expect(described_class.lookup_user_id(SolidusCicerone::SpecFixtures::User.new(3))).to eq("3")
  end

  it "builds event ids from order number and line item id" do
    order = SolidusCicerone::SpecFixtures::Order.new(number: "R55")
    line = SolidusCicerone::SpecFixtures::LineItem.new(id: 8)

    expect(described_class.event_id(order, line)).to eq("R55:8")
  end
end
