# Error tracking. Conditioned on SENTRY_DSN so nothing is sent from development, test or CI —
# the variable is only set on Heroku.
if ENV["SENTRY_DSN"].present?
  Sentry.init do |config|
    config.dsn = ENV["SENTRY_DSN"]
    config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]

    # Sample a tenth of the transactions: this is a low-traffic site, full tracing is noise.
    config.traces_sample_rate = 0.1

    # GDPR: never ship request bodies, cookies or user identifiers to a third party.
    config.send_default_pii = false

    # Tie errors to the deployed version. Requires: heroku labs:enable runtime-dyno-metadata
    config.release = ENV["HEROKU_SLUG_COMMIT"]

    # Bots probing for /wp-login.php and friends generate a constant stream of routing
    # errors that would drown out real exceptions.
    config.excluded_exceptions += [ "ActionController::RoutingError", "ActionController::BadRequest" ]
  end
end
