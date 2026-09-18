# frozen_string_literal: true

unless defined?(ActiveJob)
  module ActiveJob
    class Base
      def self.queue_as(*); end

      def self.retry_on(*); end

      def self.enqueued
        @enqueued ||= []
      end

      def self.perform_later(*args)
        enqueued << args
        true
      end

      def self.perform_now(*args)
        new.perform(*args)
      end
    end
  end
end

require "solidus_cicerone/application_job"
require "solidus_cicerone/post_events_job"
require "solidus_cicerone/post_track_job"
require "solidus_cicerone/retrain_job"
require "solidus_cicerone/export_job"
require "solidus_cicerone/order_subscriber"
require "solidus_cicerone/line_item_subscriber"
require "solidus_cicerone/extension_subscriber"
