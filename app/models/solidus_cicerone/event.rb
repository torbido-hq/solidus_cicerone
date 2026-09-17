# frozen_string_literal: true

module SolidusCicerone
  class Event < ApplicationRecord
    self.table_name = "solidus_cicerone_events"
  end
end
