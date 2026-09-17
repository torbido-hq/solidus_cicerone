# frozen_string_literal: true

require "spec_helper"

RSpec.describe Spree::CiceroneHelper do
  let(:host) do
    routes = Object.new
    def routes.cicerone_track_path(**opts)
      opts
    end

    Class.new do
      include Spree::CiceroneHelper

      def initialize(routes)
        @routes = routes
      end

      def try(*)
        nil
      end

      def spree
        @routes
      end
    end.new(routes)
  end

  it "forwards experiment fields on the click path" do
    expect(
      host.cicerone_track_path(
        item_id: "9",
        rank: 1,
        experiment_id: "exp-1",
        variant: "control",
        generated_at: "2026-09-17T03:00:00Z"
      )
    ).to include(
      item_id: "9",
      rank: 1,
      experiment_id: "exp-1",
      variant: "control",
      generated_at: "2026-09-17T03:00:00Z"
    )
  end

  it "records impressions after render" do
    recs = SolidusCicerone::Lookup::Result.new(
      user_id: "12",
      experiment_id: "exp-1",
      variant: "control",
      generated_at: "2026-09-17T03:00:00Z",
      items: [SolidusCicerone::Lookup::Item.new(item_id: "9", rank: 1)]
    )

    host.cicerone_record_impressions(recs)

    events = SolidusCicerone::PostTrackJob.enqueued.first.first
    expect(events.first).to include(
      "kind" => "impression",
      "item_id" => "9",
      "experiment_id" => "exp-1",
      "variant" => "control"
    )
  end
end
