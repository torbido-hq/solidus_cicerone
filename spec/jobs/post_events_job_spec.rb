# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidusCicerone::PostEventsJob do
  it "posts purchases built from the order" do
    order = SolidusCicerone::SpecFixtures::Order.new(
      id: 7,
      number: "R123",
      user_id: 12,
      completed_at: Time.utc(2026, 9, 17, 12, 0, 0),
      line_items: [
        SolidusCicerone::SpecFixtures::LineItem.new(
          id: 44,
          variant: SolidusCicerone::SpecFixtures::Variant.new(id: 99),
          quantity: 1
        )
      ]
    )
    stub_request(:post, "http://cicerone.test/events")
      .with { |req| JSON.parse(req.body)["event_id"] == "R123:44" }
      .to_return(status: 202, body: {"accepted" => 1}.to_json)

    described_class.perform_now(order)

    expect(WebMock).to have_requested(:post, "http://cicerone.test/events")
  end

  it "skips guest orders" do
    order = SolidusCicerone::SpecFixtures::Order.new(
      id: 7, number: "R1", user_id: nil, completed_at: Time.now.utc, line_items: []
    )

    described_class.perform_now(order)

    expect(WebMock).not_to have_requested(:post, "http://cicerone.test/events")
  end

  it "posts a prebuilt payload when given" do
    stub_request(:post, "http://cicerone.test/events")
      .to_return(status: 202, body: {"accepted" => 1}.to_json)

    described_class.perform_now(
      nil,
      [{"user_id" => "1", "item_id" => "2", "event_type" => "cart_add", "occurred_at" => "2026-09-17T12:00:00Z"}]
    )

    expect(WebMock).to have_requested(:post, "http://cicerone.test/events")
  end
end
