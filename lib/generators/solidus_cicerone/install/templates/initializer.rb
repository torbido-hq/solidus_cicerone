# frozen_string_literal: true

SolidusCicerone.configure do |config|
  config.serve_url = ENV["CICERONE_SERVE_URL"]
  config.serve_token = ENV["CICERONE_SERVE_TOKEN"]
  # Optional; defaults to serve_token (events.options.auth_token or serve token).
  config.events_token = ENV["CICERONE_EVENTS_TOKEN"]
  # Scheduler process, not serve. POST /trigger/retrain after export / catalog import / first deploy.
  config.trigger_url = ENV["CICERONE_TRIGGER_URL"]
  config.trigger_token = ENV["CICERONE_TRIGGER_TOKEN"]
  config.dashboard_url = ENV["CICERONE_DASHBOARD_URL"]
  config.cache_ttl = 45
  config.default_limit = 10
  config.enabled = true
end
