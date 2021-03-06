require File.expand_path('../boot', __FILE__)

require 'rails/all'
require File.expand_path("../../lib/active_record_monkeypatch", __FILE__)

# Assets should be precompiled for production (so we don't need the gems loaded then)
Bundler.require(*Rails.groups(assets: %w(development test)))

require File.expand_path("../../lib/ics_handler", __FILE__)
require File.expand_path("../../lib/sandbox_mail_interceptor", __FILE__)

module Scheduler
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    config.time_zone = 'Pacific Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de
    config.autoload_paths << "#{Rails.root}/app/inputs"
    config.autoload_paths << "#{Rails.root}/lib"

    config.roadie.provider = Roadie::AssetPipelineProvider.new

    #config.action_mailer.interceptors = [SandboxMailInterceptor]

    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address: ENV['SMTP_ADDRESS'] || ENV['MAILGUN_SMTP_SERVER'],
      port: ENV['SMTP_PORT'] || ENV['MAILGUN_SMTP_PORT'],
      authentication: ENV['SMTP_AUTHENTICATION'],
      user_name: ENV['SENDGRID_USERNAME'] || ENV['MAILGUN_SMTP_LOGIN'] || ENV['MANDRILL_USERNAME'],
      password: ENV['SENDGRID_PASSWORD'] || ENV['MAILGUN_SMTP_PASSWORD'] || ENV['MANDRILL_APIKEY'],
      domain: ENV['SMTP_DOMAIN'],
      enable_starttls_auto: true
    }

    config.assets.precompile += %w( es5-shim.js )
  end
  def self.table_name_prefix
    'scheduler_'
  end
end
