# frozen_string_literal: true

module Sesame
  module EmailTracking
    extend ActiveSupport::Concern

    included do
      before_action :sesame_add_tracking_headers
      after_action :sesame_log_email_attempt
    end

    private

    def sesame_add_tracking_headers
      headers["X-Mailer-Class"] = self.class.name
      headers["X-Mailer-Method"] = action_name
      headers["X-Tracking-Enabled"] = "true"

      user = sesame_resolve_user
      headers["X-User-ID"] = user.id.to_s if user&.respond_to?(:id)

    end

    def sesame_log_email_attempt
      return if message.perform_deliveries == false
      return if Thread.current[:sesame_preview_mode]

      Sesame::EmailTracker.log_email_attempt(
        message,
        sesame_resolve_user,
      )
    end

    def sesame_resolve_user
      params_user = params[:user] if respond_to?(:params, true)

      if params_user&.is_a?(::User)
        params_user
      elsif respond_to?(:params, true) && params[:user_id]
        ::User.find_by(id: params[:user_id])
      elsif message.to&.any? && ::User.column_names.include?("email")
        ::User.find_by(email: message.to.first)
      end
    end
  end
end
