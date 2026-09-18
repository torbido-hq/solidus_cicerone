# frozen_string_literal: true

module SolidusCicerone
  class ExportedUser < ApplicationRecord
    self.table_name = "solidus_cicerone_users"

    scope :cicerone_input, -> { select(*Input::USER_COLUMNS) }
  end
end
