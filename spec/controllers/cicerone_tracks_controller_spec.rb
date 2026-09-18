# frozen_string_literal: true

require "spec_helper"

module Spree
  class StoreController
    def self.skip_before_action(*); end

    def head(status)
      @status = status
    end

    attr_reader :status

    def try(*)
      nil
    end
  end
end

require_relative "../../app/controllers/spree/cicerone_tracks_controller"

RSpec.describe Spree::CiceroneTracksController do
  def dispatch(params)
    described_class.new.tap do |controller|
      controller.define_singleton_method(:params) { params }
      controller.create
    end
  end

  it "forwards a client event_id on POST /track" do
    dispatch(
      kind: "click",
      item_id: "9",
      rank: "1",
      generated_at: "2026-09-17T03:00:00Z",
      event_id: "click-9"
    )

    payload = SolidusCicerone::PostTrackJob.enqueued.first.first.first
    expect(payload).to include("event_id" => "click-9", "item_id" => "9")
  end

  it "forwards per-item event ids for a batch" do
    dispatch(
      kinds: %w[click click],
      item_ids: %w[9 8],
      ranks: %w[1 2],
      event_ids: %w[click-9 click-8]
    )

    payloads = SolidusCicerone::PostTrackJob.enqueued.first.first
    expect(payloads.map { |row| row["event_id"] }).to eq(%w[click-9 click-8])
  end
end
