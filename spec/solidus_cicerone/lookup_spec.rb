# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidusCicerone::Lookup do
  let(:user) { SolidusCicerone::SpecFixtures::User.new(12) }
  let(:client) { instance_double(SolidusCicerone::Client) }
  let(:in_stock) { SolidusCicerone::SpecFixtures::Variant.new(id: 9, stock: true) }
  let(:sold_out) { SolidusCicerone::SpecFixtures::Variant.new(id: 8, stock: false) }

  let(:body) do
    {
      "user_id" => "12",
      "fallback" => false,
      "generated_at" => "2026-09-17T03:00:00Z",
      "items" => [
        { "item_id" => "9", "rank" => 1, "score" => 0.9, "source" => "personalized" },
        { "item_id" => "8", "rank" => 2, "score" => 0.8, "source" => "personalized" }
      ]
    }
  end

  it "does not enqueue impressions unless track is on" do
    allow(client).to receive(:recommendations).and_return(body)

    described_class.call(
      user: user,
      client: client,
      stock_scope: ->(_ids) { [in_stock, sold_out] }
    )

    expect(SolidusCicerone::PostTrackJob.enqueued).to be_empty
  end

  it "filters sold-out variants and enqueues impressions for the rest" do
    allow(client).to receive(:recommendations).with("12", hash_including(limit: 10)).and_return(body)

    result = described_class.call(
      user: user,
      client: client,
      track: true,
      stock_scope: ->(_ids) { [in_stock, sold_out] }
    )

    expect(result.items.map(&:item_id)).to eq(["9"])
    expect(result.items.first.variant).to eq(in_stock)
    expect(SolidusCicerone::PostTrackJob.enqueued.size).to eq(1)
    events = SolidusCicerone::PostTrackJob.enqueued.first.first
    expect(events.first.fetch("kind")).to eq("impression")
    expect(events.first.fetch("item_id")).to eq("9")
  end

  it "requests __cold_start__ for guests" do
    allow(client).to receive(:recommendations)
      .with("__cold_start__", hash_including(limit: 4))
      .and_return("user_id" => "__cold_start__", "fallback" => true, "items" => [])

    result = described_class.call(user: nil, limit: 4, client: client, track: false, stock_scope: ->(_) { [] })

    expect(result.user_id).to eq("__cold_start__")
    expect(result.fallback).to be(true)
    expect(SolidusCicerone::PostTrackJob.enqueued).to be_empty
  end

  it "uses a short cache when one is provided" do
    store = Class.new do
      def initialize
        @hash = {}
      end

      def fetch(key, **)
        @hash[key] ||= yield
      end
    end.new

    allow(client).to receive(:recommendations).and_return(body)

    2.times do
      described_class.call(
        user: user,
        client: client,
        cache: store,
        track: false,
        stock_scope: ->(_) { [in_stock, sold_out] }
      )
    end

    expect(client).to have_received(:recommendations).once
  end

  it "returns an empty fallback list when the client errors" do
    allow(client).to receive(:recommendations).and_raise(SolidusCicerone::Error.new("down"))

    result = described_class.call(user: user, client: client, track: false)

    expect(result.items).to eq([])
    expect(result.fallback).to be(true)
  end

  it "uses SolidusCicerone.client when no client is injected" do
    allow(SolidusCicerone).to receive(:client).and_return(client)
    allow(client).to receive(:recommendations).and_return(body)

    described_class.call(user: user, track: false, stock_scope: ->(_) { [in_stock] })

    expect(SolidusCicerone).to have_received(:client)
    expect(client).to have_received(:recommendations)
  end

  it "uses Spree::Variant when no stock_scope is injected" do
    relation = Object.new
    def relation.where(*)
      []
    end
    stub_const("Spree::Variant", relation)
    allow(client).to receive(:recommendations).and_return(body)

    result = described_class.call(user: user, client: client, track: false)

    expect(result.items).to eq([])
  end

  it "does not call serve when disabled" do
    SolidusCicerone.configure { |c| c.enabled = false }
    allow(client).to receive(:recommendations)

    result = described_class.call(user: user, client: client, track: false)

    expect(result.items).to eq([])
    expect(client).not_to have_received(:recommendations)
  end
end
