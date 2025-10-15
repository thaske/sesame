# frozen_string_literal: true

require "cgi"
require "securerandom"

module Sesame
  class EmailPreviewer
    class << self
      def generate_preview(email)
        new(email).generate_preview
      end
    end

    attr_reader :email

    PreviewUser = Struct.new(:email, :id)

    def initialize(email)
      @email = email
    end

    def generate_preview
      stored_preview = metadata_value("preview_html")
      return stored_preview if stored_preview.present?

      return unless can_generate_preview?

      Thread.current[:sesame_preview_mode] = true

      mail = resolve_mail
      return generate_fallback_preview unless mail

      extract_html_content(mail) || generate_fallback_preview
    rescue StandardError => e
      Rails.logger.error("Sesame preview error: #{e.message}")
      generate_fallback_preview
    ensure
      Thread.current[:sesame_preview_mode] = false
    end

    private

    def can_generate_preview?
      email.mailer_class.present? && email.mailer_method.present? &&
        email.mailer_class.safe_constantize.present?
    end

    def metadata_value(key)
      data = email.metadata
      return unless data.is_a?(Hash)

      data[key.to_s] || data[key.to_sym]
    end

    def resolve_mail
      mail = attempt_custom_resolver
      return normalize_mail(mail) if mail

      mailer_class = email.mailer_class.safe_constantize
      return unless mailer_class&.respond_to?(email.mailer_method)

      args = Array(email.metadata&.dig("mailer_arguments"))
      args = fallback_arguments_for(mailer_class) if args.blank?
      return if args.blank?

      delivery = mailer_class.public_send(email.mailer_method, *args)
      normalize_mail(delivery)
    rescue StandardError => e
      Rails.logger.debug do
        "Sesame preview resolver failed: #{e.message}"
      end
      nil
    end

    def normalize_mail(delivery)
      return if delivery.nil?

      if delivery.respond_to?(:message)
        delivery.message
      elsif delivery.is_a?(Mail::Message)
        delivery
      end
    end

    def extract_html_content(mail)
      if mail.multipart?
        html_part =
          mail.parts.find { |part| part.content_type&.include?("text/html") }
        return html_part.body.decoded if html_part

        text_part =
          mail.parts.find { |part| part.content_type&.include?("text/plain") }
        simple_format(text_part.body.decoded) if text_part
      else
        return mail.body.decoded if mail.content_type&.include?("text/html")
        simple_format(mail.body.decoded)
      end
    end

    def simple_format(text)
      escaped = CGI.escapeHTML(text.to_s)
      "<p>#{escaped.gsub(/\n\n+/, "</p><p>").gsub("\n", "<br>")}</p>"
    end

    def attempt_custom_resolver
      resolver = Sesame.configuration.preview_resolver
      return unless resolver.respond_to?(:call)
      metadata_args = Array(email.metadata&.dig("mailer_arguments"))
      return if metadata_args.blank?

      resolver.call(email)
    rescue StandardError => e
      Rails.logger.debug do
        "Sesame preview resolver failed: #{e.message}"
      end
      nil
    end

    def fallback_arguments_for(mailer_class)
      return [] unless defined?(Devise::Mailer)
      return [] unless mailer_class <= Devise::Mailer

      devise_arguments_for(email.mailer_method)
    end

    def devise_arguments_for(method_name)
      user = resolve_devise_user
      case method_name.to_s
      when "confirmation_instructions"
        [user, devise_token_for(user, :confirmation_token), {}]
      when "reset_password_instructions"
        [user, devise_token_for(user, :reset_password_token), {}]
      when "email_changed"
        [user, {}]
      when "password_change"
        [user, {}]
      else
        []
      end
    end

    def resolve_devise_user
      return email.user if email.respond_to?(:user) && email.user

      recipient_email = email.recipient
      if defined?(::User) && ::User.respond_to?(:find_by) &&
           recipient_email.present?
        found = ::User.find_by(email: recipient_email)
        return found if found
      end

      build_preview_user(recipient_email)
    end

    def build_preview_user(recipient_email)
      return ::User.new(email: recipient_email.presence || "preview@example.com") if defined?(::User)

      PreviewUser.new(recipient_email.presence || "preview@example.com", nil)
    end

    def devise_token_for(user, column)
      return SecureRandom.hex(16) unless user

      if defined?(Devise) && Devise.respond_to?(:token_generator)
        klass = user.respond_to?(:class) ? user.class : ::User
        raw, = Devise.token_generator.generate(klass, column)
        return raw if raw.present?
      end

      SecureRandom.hex(16)
    rescue StandardError
      SecureRandom.hex(16)
    end

    def generate_fallback_preview
      <<~HTML
        <div style="padding:20px;background:#f8f9fa;border-radius:4px;color:#555;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;">
          <h4 style="margin-top:0;">Email preview not available</h4>
          <p><strong>Subject:</strong> #{CGI.escapeHTML(email.subject.to_s)}</p>
          <p><strong>Recipient:</strong> #{CGI.escapeHTML(email.recipient.to_s)}</p>
          <p><strong>Mailer:</strong> #{CGI.escapeHTML(email.mailer_class)}##{CGI.escapeHTML(email.mailer_method)}</p>
        </div>
      HTML
    end
  end
end
require "active_support/core_ext/object/blank"
