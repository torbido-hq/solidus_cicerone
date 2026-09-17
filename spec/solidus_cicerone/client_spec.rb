# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidusCicerone::Client do
  subject(:client) { described_class.from_config }

  it "GETs recommendations with bearer token and query params" do
    stub_request(:get, "http://cicerone.test/recommendations/42")
      .with(
        query: {"limit" => "5", "exclude_unavailable" => "true"},
        headers: {"Authorization" => "Bearer serve-token"}
      )
      .to_return(
        status: 200,
        headers: {"Content-Type" => "application/json"},
        body: {
          "user_id" => "42",
          "fallback" => false,
          "items" => [{"item_id" => "9", "rank" => 1, "score" => 0.8, "source" => "personalized"}]
        }.to_json
      )

    body = client.recommendations("42", limit: 5, exclude_unavailable: true)

    expect(body["items"].first["item_id"]).to eq("9")
    expect(body["fallback"]).to be(false)
  end

  it "URL-encodes user_id including the cold-start sentinel" do
    stub_request(:get, "http://cicerone.test/recommendations/#{URI.encode_www_form_component('__cold_start__')}")
      .to_return(status: 200, body: {"user_id" => "__cold_start__", "fallback" => true, "items" => []}.to_json)

    body = client.recommendations(SolidusCicerone::Ids::COLD_START)

    expect(body["fallback"]).to be(true)
  end

  it "POSTs a single event object to /events with the events token" do
    stub_request(:post, "http://cicerone.test/events")
      .with(
        headers: {
          "Authorization" => "Bearer events-token",
          "Content-Type" => "application/json"
        },
        body: {
          "user_id" => "1",
          "item_id" => "9",
          "event_type" => "purchase",
          "quantity" => 2,
          "occurred_at" => "2026-09-17T12:00:00Z",
          "event_id" => "R123:44"
        }.to_json
      )
      .to_return(status: 202, body: {"accepted" => 1, "event_ids" => ["R123:44"]}.to_json)

    body = client.post_events(
      {
        "user_id" => "1",
        "item_id" => "9",
        "event_type" => "purchase",
        "quantity" => 2,
        "occurred_at" => "2026-09-17T12:00:00Z",
        "event_id" => "R123:44"
      }
    )

    expect(body["accepted"]).to eq(1)
  end

  it "wraps multiple events under events[]" do
    stub_request(:post, "http://cicerone.test/events")
      .with { |req| JSON.parse(req.body).fetch("events").size == 2 }
      .to_return(status: 202, body: {"accepted" => 2, "event_ids" => %w[a b]}.to_json)

    body = client.post_events(
      [
        {"user_id" => "1", "item_id" => "9", "event_type" => "purchase", "occurred_at" => "2026-09-17T12:00:00Z"},
        {"user_id" => "1", "item_id" => "8", "event_type" => "purchase", "occurred_at" => "2026-09-17T12:00:00Z"}
      ]
    )

    expect(body["accepted"]).to eq(2)
  end

  it "POSTs /track with the serve token" do
    stub_request(:post, "http://cicerone.test/track")
      .with(headers: {"Authorization" => "Bearer serve-token"})
      .to_return(status: 200, body: {"accepted" => 1}.to_json)

    body = client.post_track(
      "kind" => "impression",
      "user_id" => "1",
      "item_id" => "9",
      "occurred_at" => "2026-09-17T12:00:00Z",
      "rank" => 1
    )

    expect(body["accepted"]).to eq(1)
  end

  it "POSTs /trigger/retrain on the scheduler URL" do
    stub_request(:post, "http://cicerone-trigger.test/trigger/retrain")
      .with(headers: {"Authorization" => "Bearer trigger-token"})
      .to_return(status: 202, body: {"status" => "started"}.to_json)

    expect(client.trigger_retrain).to eq("status" => "started")
  end

  it "raises RetryableError on 429" do
    stub_request(:post, "http://cicerone.test/events")
      .to_return(status: 429, body: {"detail" => "backlog"}.to_json)

    expect {
      client.post_events("user_id" => "1", "item_id" => "9", "event_type" => "purchase", "occurred_at" => "2026-09-17T12:00:00Z")
    }.to raise_error(SolidusCicerone::RetryableError, /429/)
  end

  it "raises Error on 400" do
    stub_request(:get, "http://cicerone.test/recommendations/1")
      .to_return(status: 400, body: {"detail" => "conflicting limit and k"}.to_json)

    expect { client.recommendations("1") }.to raise_error(SolidusCicerone::Error, /400/)
  end

  it "requires serve_url" do
    bare = described_class.new(base_url: nil)

    expect { bare.recommendations("1") }.to raise_error(SolidusCicerone::ConfigurationError)
  end
end
