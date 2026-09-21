# frozen_string_literal: true

require "solidus_core"
require "solidus_support"

module SolidusCicerone
  class Engine < Rails::Engine
    include SolidusSupport::EngineExtensions

    isolate_namespace ::Spree

    engine_name "solidus_cicerone"

    rake_tasks do
      load File.expand_path("../tasks/solidus_cicerone.rake", __dir__)
    end

    config.generators do |g|
      g.test_framework :rspec
    end

    initializer "solidus_cicerone.helpers", after: "spree.environment" do
      ActiveSupport.on_load(:action_controller) do
        helper Spree::CiceroneHelper if respond_to?(:helper)
      end
    end

    initializer "solidus_cicerone.admin_menu" do
      next unless defined?(Spree::Backend::Config)

      Spree::Backend::Config.configure do |config|
        config.menu_items << admin_menu_item(config)
      end
    rescue ArgumentError, NoMethodError
      nil
    end

    config.to_prepare do
      SolidusCicerone::EventStore.ensure_active_record!
      SolidusCicerone::OrderSubscriber.new.subscribe_to(Spree::Bus)
      SolidusCicerone::LineItemSubscriber.install
      SolidusCicerone::ExtensionSubscriber.install
    end

    def self.admin_menu_item(config)
      item_class = config.class::MenuItem
      condition = -> { respond_to?(:can?) ? can?(:admin, Spree::Order) : true }
      item_class.new(
        label: :cicerone,
        icon: "ribbon-b",
        url: :admin_cicerone_path,
        condition: condition
      )
    rescue ArgumentError
      item_class.new([:cicerone], "star", url: :admin_cicerone_path, condition: -> { true })
    end
  end
end
