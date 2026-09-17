# frozen_string_literal: true

module SolidusCicerone
  module SpecFixtures
    LineItem = Struct.new(:id, :variant, :variant_id, :quantity, :order, keyword_init: true)
    Taxon = Struct.new(:id, :name, :lft, :position, keyword_init: true)
    Country = Struct.new(:iso, keyword_init: true)
    Address = Struct.new(:country, :country_iso, keyword_init: true)
    Product = Struct.new(:slug, :taxons, :available, :available_on, :discontinue_on, :master, keyword_init: true) do
      def available?
        available.nil? ? true : available
      end
    end
    Variant = Struct.new(:id, :stock, :product, keyword_init: true) do
      def in_stock?
        stock
      end
    end
    User = Struct.new(:id, :bill_address, :ship_address)
    Order = Struct.new(:id, :number, :user_id, :completed_at, :line_items, :user, keyword_init: true)
    Review = Struct.new(:id, :user, :product, :variant, :rating, :created_at, keyword_init: true)
    WishedItem = Struct.new(:id, :user, :variant, :created_at, keyword_init: true)
  end
end
