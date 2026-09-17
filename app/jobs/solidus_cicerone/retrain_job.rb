# frozen_string_literal: true

module SolidusCicerone
  class RetrainJob < ApplicationJob
    def perform
      return unless SolidusCicerone.enabled?

      SolidusCicerone.client.trigger_retrain
    end
  end
end
