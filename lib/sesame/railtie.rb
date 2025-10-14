# frozen_string_literal: true

module Sesame
  class Railtie < Rails::Railtie
    # Register the email tracking interceptor
    initializer "sesame.interceptor" do
      ActiveSupport.on_load(:action_mailer) do
        ActionMailer::Base.register_interceptor(
          Sesame::Interceptors::EmailTrackingInterceptor
        )
      end
    end

    # Auto-configure RailsAdmin if it's loaded
    initializer "sesame.rails_admin", after: "rails_admin.init" do
      if defined?(RailsAdmin)
        require "sesame/rails_admin_config"
        Sesame::RailsAdminConfig.setup
      end
    end
  end
end
