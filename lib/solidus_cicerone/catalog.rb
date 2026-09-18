# frozen_string_literal: true

require "solidus_cicerone/event_payload"
require "solidus_cicerone/ids"

module SolidusCicerone
  module Catalog
    FALLBACK_CATEGORY = "uncategorized"
    POSITIVE_REVIEW = 4
    NEGATIVE_REVIEW = 2

    module_function

    def item_row(variant)
      product = variant.respond_to?(:product) ? variant.product : nil
      {
        "item_id" => Ids.item_id_for(variant),
        "category" => category_for(product),
        "published" => published?(product),
        "in_stock" => in_stock?(variant)
      }
    end

    def user_row(user)
      {
        "user_id" => Ids.user_id_for(user),
        "country" => country_for(user)
      }
    end

    def review_event(review)
      user = review.respond_to?(:user) ? review.user : review
      item = review_item(review)
      rating = review.respond_to?(:rating) ? review.rating.to_i : 0
      event_type = review_event_type(rating)
      return if event_type.nil?

      EventPayload.interaction(
        user: user,
        item: item,
        event_type: event_type,
        occurred_at: review.respond_to?(:created_at) ? review.created_at : nil,
        event_id: "review:#{review.id}"
      )
    end

    def wishlist_event(item)
      user = item.respond_to?(:user) ? item.user : item
      variant = item.respond_to?(:variant) ? item.variant : item
      EventPayload.interaction(
        user: user,
        item: variant,
        event_type: "saved",
        occurred_at: item.respond_to?(:created_at) ? item.created_at : nil,
        event_id: "saved:#{item.id}"
      )
    end

    def category_for(product)
      return FALLBACK_CATEGORY if product.nil?

      taxon = primary_taxon(product)
      name = taxon.respond_to?(:name) ? taxon.name : taxon
      return name.to_s unless name.nil? || name.to_s.empty?

      slug = product.respond_to?(:slug) ? product.slug : nil
      slug.nil? || slug.to_s.empty? ? FALLBACK_CATEGORY : slug.to_s
    end

    def primary_taxon(product)
      taxons = product.respond_to?(:taxons) ? product.taxons : nil
      return if taxons.nil?

      return taxons.order(:lft).first if taxons.respond_to?(:order)

      Array(taxons).min_by { |taxon| [taxon_lft(taxon), taxon.respond_to?(:id) ? taxon.id.to_i : 0] }
    end

    def taxon_lft(taxon)
      return taxon.lft if taxon.respond_to?(:lft) && !taxon.lft.nil?
      return taxon.position if taxon.respond_to?(:position) && !taxon.position.nil?

      0
    end

    def published?(product)
      return false if product.nil?
      return product.available? if product.respond_to?(:available?)

      now = EventPayload.now_utc
      available_on = product.respond_to?(:available_on) ? product.available_on : nil
      discontinue_on = product.respond_to?(:discontinue_on) ? product.discontinue_on : nil
      (available_on.nil? || available_on <= now) && (discontinue_on.nil? || discontinue_on > now)
    end

    def in_stock?(variant)
      return true unless variant.respond_to?(:in_stock?)

      variant.in_stock? == true
    end

    def country_for(user)
      return if user.nil?

      address = first_present(user, :bill_address, :ship_address, :default_address)
      return address.country_iso if address.respond_to?(:country_iso) && present?(address.country_iso)

      country = address.respond_to?(:country) ? address.country : nil
      return country.iso if country.respond_to?(:iso) && present?(country.iso)
      return country.to_s if country && !country.respond_to?(:iso) && present?(country)

      nil
    end

    def review_item(review)
      return review.variant if review.respond_to?(:variant) && review.variant
      if review.respond_to?(:product) && review.product.respond_to?(:master) && review.product.master
        return review.product.master
      end

      review.respond_to?(:product) ? review.product : review
    end

    def review_event_type(rating)
      return "review_positive" if rating >= POSITIVE_REVIEW
      return "review_negative" if rating <= NEGATIVE_REVIEW && rating.positive?

      nil
    end

    def first_present(record, *methods)
      methods.each do |name|
        next unless record.respond_to?(name)

        value = record.public_send(name)
        return value unless value.nil?
      end
      nil
    end

    def present?(value)
      !value.nil? && !value.to_s.empty?
    end
  end
end
