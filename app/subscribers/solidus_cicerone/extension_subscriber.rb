# frozen_string_literal: true

module SolidusCicerone
  class ExtensionSubscriber
    def self.install
      install_on(review_class, :solidus_cicerone_record_review, :on_review)
      install_on(wishlist_class, :solidus_cicerone_record_saved, :on_saved)
    end

    def self.on_review(review)
      SolidusCicerone.record_event(Catalog.review_event(review))
    end

    def self.on_saved(item)
      SolidusCicerone.record_event(Catalog.wishlist_event(item))
    end

    def self.install_on(klass, method_name, handler)
      return if klass.nil?
      return unless klass.respond_to?(:after_create_commit)
      return if klass.method_defined?(method_name)

      subscriber = self
      klass.after_create_commit do
        subscriber.public_send(handler, self)
      end
    end

    def self.review_class
      return Spree::Review if Spree.const_defined?(:Review, false)

      nil
    end

    def self.wishlist_class
      return Spree::WishedItem if Spree.const_defined?(:WishedItem, false)
      return Spree::WishlistItem if Spree.const_defined?(:WishlistItem, false)

      nil
    end
  end
end
