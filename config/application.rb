require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Cyrillepierre
  class Application < Rails::Application
    config.generators do |generate|
      generate.assets false
      generate.helper false
      generate.test_framework :test_unit, fixture: false
    end

    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.time_zone = "Paris"
    # config.eager_load_paths << Rails.root.join("extras")

    # Encrypts sensitive Active Record attributes (e.g. User#linkedin_access_token). Keys come
    # from ENV, like every other secret in this app, rather than credentials.yml.enc.
    config.active_record.encryption.primary_key = ENV.fetch("AR_ENCRYPTION_PRIMARY_KEY", nil)
    config.active_record.encryption.deterministic_key = ENV.fetch("AR_ENCRYPTION_DETERMINISTIC_KEY", nil)
    config.active_record.encryption.key_derivation_salt = ENV.fetch("AR_ENCRYPTION_KEY_DERIVATION_SALT", nil)
  end
end
