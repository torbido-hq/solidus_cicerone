# frozen_string_literal: true

module Spree
  module CiceroneHelper
    def cicerone_recommendations(user: try(:spree_current_user), **opts)
      SolidusCicerone.recommendations_for(user, **opts)
    end

    def cicerone_track_path(item_id:, rank: nil, kind: "click")
      spree.cicerone_track_path(
        item_id: item_id,
        rank: rank,
        kind: kind
      )
    end
  end
end
