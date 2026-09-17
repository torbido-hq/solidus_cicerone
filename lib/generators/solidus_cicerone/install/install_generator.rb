# frozen_string_literal: true

module SolidusCicerone
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      def self.exit_on_failure?
        true
      end

      def copy_initializer
        template "initializer.rb", "config/initializers/solidus_cicerone.rb"
      end

      def copy_cicerone_sql_example
        template "cicerone.solidus.toml", "config/cicerone.solidus.toml"
      end
    end
  end
end
