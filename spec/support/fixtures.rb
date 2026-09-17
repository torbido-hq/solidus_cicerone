# frozen_string_literal: true

module SolidusCicerone
  module SpecFixtures
    LineItem = Struct.new(:id, :variant, :variant_id, :quantity, keyword_init: true)
    Variant = Struct.new(:id, :stock, keyword_init: true) do
      def in_stock?
        stock
      end
    end
    User = Struct.new(:id)
    Order = Struct.new(:id, :number, :user_id, :completed_at, :line_items, keyword_init: true)
  end
end
