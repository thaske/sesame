# frozen_string_literal: true

require "cgi"

module Sesame
  class EmailPreviewer
    class << self
      def generate_preview(email)
        new(email).generate_preview
      end
    end

    attr_reader :email

    def initialize(email)
      @email = email
    end

    def generate_preview
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

    def resolve_mail
      resolver = Sesame.configuration.preview_resolver
      mail = resolver.call(email) if resolver.respond_to?(:call)
      return normalize_mail(mail) if mail

      mailer_class = email.mailer_class.safe_constantize
      return unless mailer_class&.respond_to?(email.mailer_method)

      args = Array(email.metadata&.dig("mailer_arguments"))
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
