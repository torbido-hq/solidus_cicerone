# frozen_string_literal: true

module SolidusCicerone
  class ExportJob < ApplicationJob
    def perform
      return unless SolidusCicerone.enabled?

      Exporter.call
    end
  end
end
