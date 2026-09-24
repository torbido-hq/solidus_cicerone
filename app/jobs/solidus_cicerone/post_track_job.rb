# frozen_string_literal: true

module SolidusCicerone
  class PostTrackJob < ApplicationJob
    def perform(events)
      return unless SolidusCicerone.enabled?

      list = Array(events).compact
      return if list.empty?

      SolidusCicerone.client.track(list)
    end
  end
end
