# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidusCicerone::Configuration do
  it "assigns typed admin attrs" do
    config = described_class.new
    config.assign("cache_ttl" => "30", "enabled" => "true", "serve_url" => " http://x ")

    expect(config.cache_ttl).to eq(30)
    expect(config.enabled?).to be(true)
    expect(config.serve_url).to eq("http://x")
  end

  it "can be disabled" do
    SolidusCicerone.configure { |c| c.enabled = false }

    expect(SolidusCicerone.enabled?).to be(false)
  end

  it "falls events token back to the serve token" do
    SolidusCicerone.configure { |c| c.events_token = nil }

    expect(SolidusCicerone.events_token).to eq("serve-token")
  end
end
