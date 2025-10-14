# frozen_string_literal: true

module Sesame
  module Interceptors
    class EmailTrackingInterceptor
      class << self
        def delivering_email(mail)
          nil unless tracking_enabled?(mail)
        end

        def delivered_email(mail)
          return unless tracking_enabled?(mail)

          message_id = mail.message_id
          user = resolve_user(mail)

          if message_id
            Sesame::EmailTracker.log_email_sent(
              mail,
              message_id,
              user,
            )
          end
        end

        private

        def tracking_enabled?(mail)
          mail.header["X-Tracking-Enabled"]&.value == "true"
        end

        def resolve_user(mail)
          user_id = mail.header["X-User-ID"]&.value
          return ::User.find_by(id: user_id) if user_id

          recipient_email = mail.to&.first
          if recipient_email && ::User.column_names.include?("email")
            return ::User.find_by(email: recipient_email)
          end

          nil
        end
      end
    end
  end
end
