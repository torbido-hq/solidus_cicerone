# frozen_string_literal: true

module SolidusCicerone
  class ExportedItem < ApplicationRecord
    self.table_name = "solidus_cicerone_items"

    scope :cicerone_input, -> { select(*Input::ITEM_COLUMNS) }
  end
end
