ENV["RAILS_ENV"] ||= "test"

# Doit être chargé avant l'application pour instrumenter tout le code.
require "simplecov"
SimpleCov.start "rails" do
  enable_coverage :branch
  skip "/test/"
end

require_relative "../config/environment"
require "rails/test_help"

# Fournit Object#stub, utilisé pour remplacer les passerelles LLM le temps d'un test.
require "minitest/mock"

# Aucun appel réseau réel depuis la suite : un test qui oublie de stubber une requête
# échoue explicitement au lieu de taper sur Mammouth, LinkedIn ou Cloudinary.
require "webmock/minitest"
WebMock.disable_net_connect!(allow_localhost: true)

# Les throttles compteraient les requêtes de toute la suite depuis la même IP et
# renverraient des 429 sans rapport avec le test en cours. Réactivé explicitement dans
# test/integration/rate_limiting_test.rb.
Rack::Attack.enabled = false

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Les tests parallèles tournent dans des processus forkés : sans nom de commande distinct
    # par worker puis fusion à la fin, SimpleCov ne rapporterait que la couverture du dernier.
    parallelize_setup do |worker|
      SimpleCov.command_name "#{SimpleCov.command_name}-#{worker}"
    end

    parallelize_teardown do |_worker|
      SimpleCov.result
    end

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end
