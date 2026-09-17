# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidusCicerone::ExtensionSubscriber do
  it "records a positive review when the extension fires" do
    review = SolidusCicerone::SpecFixtures::Review.new(
      id: 11,
      user: SolidusCicerone::SpecFixtures::User.new(4),
      variant: SolidusCicerone::SpecFixtures::Variant.new(id: 8),
      rating: 5
    )

    described_class.on_review(review)

    expect(SolidusCicerone::EventStore.backend.events.fetch("review:11")).to include(
      "event_type" => "review_positive",
      "item_id" => "8"
    )
  end

  it "records a wishlist save when the extension fires" do
    item = SolidusCicerone::SpecFixtures::WishedItem.new(
      id: 6,
      user: SolidusCicerone::SpecFixtures::User.new(4),
      variant: SolidusCicerone::SpecFixtures::Variant.new(id: 8)
    )

    described_class.on_saved(item)

    expect(SolidusCicerone::EventStore.backend.events.fetch("saved:6")).to include(
      "event_type" => "saved",
      "user_id" => "4"
    )
  end
end
