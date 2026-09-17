# frozen_string_literal: true

module SolidusCicerone
  class ExportedUser < ApplicationRecord
    self.table_name = "solidus_cicerone_users"
  end
end
