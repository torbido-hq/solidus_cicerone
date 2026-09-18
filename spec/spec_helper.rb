# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  enable_coverage :line
  add_filter "/spec/"
  add_filter "lib/solidus_cicerone/engine.rb"
  add_filter "lib/generators/"
  track_files "{lib,app/jobs,app/subscribers,app/helpers}/**/*.rb"
  minimum_coverage 95
end

require "webmock/rspec"

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
$LOAD_PATH.unshift File.expand_path("../app/jobs", __dir__)
$LOAD_PATH.unshift File.expand_path("../app/subscribers", __dir__)
$LOAD_PATH.unshift File.expand_path("../app/helpers", __dir__)

require "solidus_cicerone"
require "spree/cicerone_helper"
require "support/fixtures"
require "support/active_job_stub"

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before do
    SolidusCicerone.reset_configuration!
    SolidusCicerone.configure do |c|
      c.serve_url = "http://cicerone.test"
      c.serve_token = "serve-token"
      c.events_token = "events-token"
      c.trigger_url = "http://cicerone-trigger.test"
      c.trigger_token = "trigger-token"
      c.enabled = true
    end
    SolidusCicerone::EventStore.backend = SolidusCicerone::EventStore::Memory.new
    SolidusCicerone::PostEventsJob.enqueued.clear if defined?(SolidusCicerone::PostEventsJob)
    SolidusCicerone::PostTrackJob.enqueued.clear if defined?(SolidusCicerone::PostTrackJob)
    SolidusCicerone::RetrainJob.enqueued.clear if defined?(SolidusCicerone::RetrainJob)
    SolidusCicerone::ExportJob.enqueued.clear if defined?(SolidusCicerone::ExportJob)
  end
end
