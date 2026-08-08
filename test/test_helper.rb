ENV["RAILS_ENV"] ||= "test"

# Doit être chargé avant l'application pour instrumenter tout le code.
require "simplecov"
SimpleCov.start "rails" do
  enable_coverage :branch
  skip "/test/"
end

require_relative "../config/environment"
require "rails/test_help"

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
