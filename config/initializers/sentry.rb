# Error tracking. Conditioned on SENTRY_DSN so nothing is sent from development, test or CI —
# the variable is only set on Heroku.
#
# Les processus jetables — `rails runner` (scripts de vérification lancés sur un dyno `heroku run`,
# qui reçoit les mêmes variables que la production) et `rails console` — ne sont pas de la
# production : une exception qui y remonte est un script qui a échoué, pas un visiteur touché.
# Le 17/09/2026 un `raise "repère introuvable"` dans un script /tmp/p.rb est arrivé dans Sentry
# comme un crash, et deux appels manqués le 23/09. Rails ne charge que la classe de la commande
# invoquée : sa présence dit dans quel processus on est (vérifié sur Rails 8.1).
disposable_process = defined?(Rails::Command::RunnerCommand) || defined?(Rails::Command::ConsoleCommand)

if ENV["SENTRY_DSN"].present? && !disposable_process
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
