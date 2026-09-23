require "test_helper"

# Sentry ne s'initialise qu'avec un DSN, et jamais dans un processus jetable (`rails runner`,
# `rails console`) : un script de vérification qui échoue sur un dyno `heroku run` n'est pas un
# crash de production. Le processus de test ne charge aucune de ces deux classes de commande.
class SentryInitializerTest < ActiveSupport::TestCase
  INITIALIZER = Rails.root.join("config/initializers/sentry.rb")

  setup do
    @dsn = ENV["SENTRY_DSN"]
    assert_not defined?(Rails::Command::RunnerCommand), "le processus de test ne doit pas passer pour un runner"
    assert_not Sentry.initialized?
  end

  teardown do
    ENV["SENTRY_DSN"] = @dsn
    Rails::Command.send(:remove_const, :RunnerCommand) if Rails::Command.const_defined?(:RunnerCommand, false)
    Sentry.close if Sentry.initialized?
  end

  test "stays off without a DSN, and off in a runner process even with one" do
    ENV["SENTRY_DSN"] = nil
    load INITIALIZER
    assert_not Sentry.initialized?

    ENV["SENTRY_DSN"] = "https://cle@o0.ingest.sentry.io/1"
    Rails::Command.const_set(:RunnerCommand, Class.new)
    load INITIALIZER
    assert_not Sentry.initialized?, "un script runner ne doit rien envoyer à Sentry"
  end

  test "initialises with a DSN in an ordinary process, without PII and with the bot noise excluded" do
    ENV["SENTRY_DSN"] = "https://cle@o0.ingest.sentry.io/1"
    load INITIALIZER

    assert Sentry.initialized?
    assert_not Sentry.configuration.send_default_pii
    assert_includes Sentry.configuration.excluded_exceptions, "ActionController::RoutingError"
    assert_in_delta 0.1, Sentry.configuration.traces_sample_rate
  end
end
