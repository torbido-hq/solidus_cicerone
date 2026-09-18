# frozen_string_literal: true

SolidusCicerone.configure do |config|
  config.serve_url = ENV.fetch("CICERONE_SERVE_URL", nil)
  config.serve_token = ENV.fetch("CICERONE_SERVE_TOKEN", nil)
  # Optional; defaults to serve_token (events.options.auth_token or serve token).
  config.events_token = ENV.fetch("CICERONE_EVENTS_TOKEN", nil)
  # Scheduler process, not serve. POST /trigger/retrain after export / catalog import / first deploy.
  config.trigger_url = ENV.fetch("CICERONE_TRIGGER_URL", nil)
  config.trigger_token = ENV.fetch("CICERONE_TRIGGER_TOKEN", nil)
  config.dashboard_url = ENV.fetch("CICERONE_DASHBOARD_URL", nil)
  config.cache_ttl = 45
  config.default_limit = 10
  config.enabled = true
end
