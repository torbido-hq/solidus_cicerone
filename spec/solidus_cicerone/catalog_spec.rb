# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidusCicerone::Catalog do
  it "keeps one item row and the first taxon by lft" do
    product = SolidusCicerone::SpecFixtures::Product.new(
      slug: "lager",
      taxons: [
        SolidusCicerone::SpecFixtures::Taxon.new(id: 2, name: "Seasonal", lft: 8),
        SolidusCicerone::SpecFixtures::Taxon.new(id: 1, name: "Beer", lft: 1)
      ]
    )
    variant = SolidusCicerone::SpecFixtures::Variant.new(id: 9, stock: true, product: product)

    expect(described_class.item_row(variant)).to eq(
      "item_id" => "9",
      "category" => "Beer",
      "published" => true,
      "in_stock" => true
    )
  end

  it "falls back to product slug when there are no taxons" do
    product = SolidusCicerone::SpecFixtures::Product.new(slug: "pale-ale", taxons: [])
    variant = SolidusCicerone::SpecFixtures::Variant.new(id: 4, stock: false, product: product)

    expect(described_class.item_row(variant)).to include("category" => "pale-ale", "in_stock" => false)
  end

  it "exports a user country from the bill address" do
    user = SolidusCicerone::SpecFixtures::User.new(
      12,
      SolidusCicerone::SpecFixtures::Address.new(
        country: SolidusCicerone::SpecFixtures::Country.new(iso: "IT")
      ),
      nil
    )

    expect(described_class.user_row(user)).to eq("user_id" => "12", "country" => "IT")
  end

  it "maps review ratings to Cicerone event types" do
    user = SolidusCicerone::SpecFixtures::User.new(3)
    variant = SolidusCicerone::SpecFixtures::Variant.new(id: 9)
    positive = SolidusCicerone::SpecFixtures::Review.new(id: 1, user: user, variant: variant, rating: 5)
    negative = SolidusCicerone::SpecFixtures::Review.new(id: 2, user: user, variant: variant, rating: 1)
    skip = SolidusCicerone::SpecFixtures::Review.new(id: 3, user: user, variant: variant, rating: 3)

    expect(described_class.review_event(positive)).to include("event_type" => "review_positive", "event_id" => "review:1")
    expect(described_class.review_event(negative)).to include("event_type" => "review_negative")
    expect(described_class.review_event(skip)).to be_nil
  end
end
