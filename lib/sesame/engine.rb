# frozen_string_literal: true

require "rails/engine"

module Sesame
  class Engine < ::Rails::Engine
    isolate_namespace Sesame

    config.generators.test_framework :rspec

    initializer "sesame.action_mailer" do
      ActiveSupport.on_load(:action_mailer) do
        ActionMailer::Base.include Sesame::EmailTracking
        ActionMailer::Base.register_observer(
          Sesame::Interceptors::EmailTrackingInterceptor,
        )
      end
    end
  end
end
