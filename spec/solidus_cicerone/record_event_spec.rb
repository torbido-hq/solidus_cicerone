# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidusCicerone, ".record_event" do
  it "upserts the export row and enqueues POST /events" do
    payload = {
      "user_id" => "1",
      "item_id" => "9",
      "event_type" => "view",
      "quantity" => 1,
      "occurred_at" => "2026-09-17T12:00:00Z",
      "event_id" => "view:1:9"
    }

    described_class.record_event(payload)

    expect(described_class::EventStore.backend.events["view:1:9"]).to include("event_type" => "view")
    expect(described_class::PostEventsJob.enqueued.first.first).to contain_exactly(
      hash_including("event_id" => "view:1:9")
    )
  end

  it "records a signed-in product view" do
    described_class.record_view(
      SolidusCicerone::SpecFixtures::User.new(4),
      SolidusCicerone::SpecFixtures::Variant.new(id: 8)
    )

    event = described_class::EventStore.backend.events.values.first
    expect(event).to include("event_type" => "view", "user_id" => "4", "item_id" => "8")
  end

  it "enqueues an export" do
    described_class.enqueue_export

    expect(described_class::ExportJob.enqueued).to eq([[]])
  end

  it "enqueues a retrain" do
    described_class.enqueue_retrain

    expect(described_class::RetrainJob.enqueued).to eq([[]])
  end

  it "reads the dashboard url and forwards recommendations" do
    SolidusCicerone.configure { |c| c.dashboard_url = "http://dash.test" }
    recs = Cicerone::Recommendations.new(
      generated_at: nil, user_id: "1", fallback: false, items: [], experiment_id: nil, variant: nil
    )
    client = instance_double(Cicerone::Client, recommendations: recs)
    allow(described_class).to receive(:client).and_return(client)

    expect(described_class.dashboard_url).to eq("http://dash.test")
    described_class.recommendations_for(
      SolidusCicerone::SpecFixtures::User.new(1),
      client: client,
      track: false,
      stock_scope: ->(_) { [] }
    )

    expect(client).to have_received(:recommendations)
  end
end
