# frozen_string_literal: true

module Spree
  module CiceroneHelper
    def cicerone_recommendations(user: try(:spree_current_user), **opts)
      SolidusCicerone.recommendations_for(user, **opts)
    end

    def cicerone_record_impressions(recs)
      SolidusCicerone.enqueue_impressions(recs)
    end

    def cicerone_record_view(variant, user: try(:spree_current_user))
      SolidusCicerone.record_view(user, variant)
    end

    def cicerone_track_path(item_id:, rank: nil, kind: "click", experiment_id: nil, variant: nil, generated_at: nil,
                            event_id: nil)
      spree.cicerone_track_path(
        item_id: item_id,
        rank: rank,
        kind: kind,
        experiment_id: experiment_id,
        variant: variant,
        generated_at: generated_at,
        event_id: event_id
      )
    end
  end
end
