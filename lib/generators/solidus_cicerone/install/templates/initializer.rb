# frozen_string_literal: true

# Rails-side settings only. Cicerone TOML stays on the Cicerone deploy.
# See README “Configure” for the ENV table, jobs, and Cicerone [input] queries.
#
# cache_ttl, default_limit, and enabled also read CICERONE_CACHE_TTL,
# CICERONE_DEFAULT_LIMIT, and CICERONE_ENABLED when you do not set them here.
SolidusCicerone.configure do |config|
  config.serve_url = ENV.fetch("CICERONE_SERVE_URL", nil)
  config.serve_token = ENV.fetch("CICERONE_SERVE_TOKEN", nil)
  # Optional; defaults to serve_token (events.options.auth_token or serve token).
  config.events_token = ENV.fetch("CICERONE_EVENTS_TOKEN", nil)
  # Scheduler process, not serve. POST /trigger/retrain after export / catalog import / first deploy.
  config.trigger_url = ENV.fetch("CICERONE_TRIGGER_URL", nil)
  config.trigger_token = ENV.fetch("CICERONE_TRIGGER_TOKEN", nil)
  config.dashboard_url = ENV.fetch("CICERONE_DASHBOARD_URL", nil)
end

# After db:migrate, EventStore uses ActiveRecord when the export tables exist.
# Null is the default until then.
