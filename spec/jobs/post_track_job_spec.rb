# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidusCicerone::PostTrackJob do
  it "posts track events" do
    stub_request(:post, "http://cicerone.test/track")
      .to_return(status: 200, body: { "accepted" => 1 }.to_json)

    described_class.perform_now(
      [{ "kind" => "click", "user_id" => "1", "item_id" => "9", "occurred_at" => "2026-09-17T12:00:00Z" }]
    )

    expect(WebMock).to have_requested(:post, "http://cicerone.test/track")
  end

  it "no-ops on an empty list" do
    described_class.perform_now([])

    expect(WebMock).not_to have_requested(:post, "http://cicerone.test/track")
  end
end
