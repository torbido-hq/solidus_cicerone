# frozen_string_literal: true

module Spree
  class CiceroneTracksController < Spree::StoreController
    skip_before_action :verify_authenticity_token, raise: false

    def create
      events = Array(track_events).compact
      SolidusCicerone.enqueue_track(events) if events.any?
      head :accepted
    end

    private

    def track_events
      user_id = track_user_id
      kinds = Array(params[:kind] || params[:kinds] || "click")
      item_ids = Array(params[:item_id] || params[:item_ids])
      ranks = Array(params[:rank] || params[:ranks])
      event_ids = Array(params[:event_id] || params[:event_ids])

      item_ids.each_with_index.map do |item_id, index|
        next if item_id.to_s.empty?

        SolidusCicerone::EventPayload.track(
          kind: kinds[index] || kinds.first || "click",
          user_id: user_id,
          item_id: item_id,
          rank: ranks[index],
          experiment_id: params[:experiment_id],
          variant: params[:variant],
          generated_at: params[:generated_at],
          event_id: event_ids[index]
        )
      end
    end

    def track_user_id
      user = try(:spree_current_user)
      return SolidusCicerone::Ids.user_id_for(user) if user

      SolidusCicerone::Ids::COLD_START
    end
  end
end
