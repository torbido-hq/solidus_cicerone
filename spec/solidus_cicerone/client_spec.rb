# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidusCicerone, ".client" do
  it "builds a Cicerone client from settings" do
    client = described_class.client

    expect(client).to be_a(Cicerone::Client)
    expect(client.url).to eq("http://cicerone.test")
    expect(client.token).to eq("serve-token")
    expect(client.events_token).to eq("events-token")
    expect(client.trigger_url).to eq("http://cicerone-trigger.test")
    expect(client.trigger_token).to eq("trigger-token")
  end

  it "forwards the faraday builder hook" do
    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.get("/health") do
      [200, { "Content-Type" => "application/json" }, '{"status":"ok"}']
    end
    SolidusCicerone.configure do |config|
      config.faraday = ->(faraday) { faraday.adapter :test, stubs }
    end

    expect(described_class.client.health.status).to eq("ok")
    stubs.verify_stubbed_calls
  end
end
