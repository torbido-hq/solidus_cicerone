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

  it "no-ops install when review and wishlist classes are absent" do
    expect { described_class.install }.not_to raise_error
  end

  it "installs after_create_commit on an extension class" do
    klass = Class.new do
      def self.after_create_commit(&block)
        @block = block
      end

      def self.callback
        @block
      end
    end

    described_class.install_on(klass, :solidus_cicerone_record_review, :on_review)

    expect(klass.callback).to be_a(Proc)
  end

  it "resolves optional Solidus extension constants" do
    stub_const("Spree::Review", Class.new)
    stub_const("Spree::WishedItem", Class.new)

    expect(described_class.review_class).to eq(Spree::Review)
    expect(described_class.wishlist_class).to eq(Spree::WishedItem)
  end

  it "falls back to WishlistItem when WishedItem is missing" do
    stub_const("Spree::WishlistItem", Class.new)
    hide_const("Spree::WishedItem") if defined?(Spree::WishedItem)

    expect(described_class.wishlist_class).to eq(Spree::WishlistItem)
  end
end
