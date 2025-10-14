# frozen_string_literal: true

require "json"

module Sesame
  class EmailTracker
    class << self
      def log_email_attempt(mail, user = nil)
        new(mail, user).log_attempt
      end

      def log_email_sent(mail, message_id, user = nil)
        new(mail, user).log_sent(message_id)
      end

      def log_email_delivery(
        message_id,
        timestamp = Time.current,
        event_data = {}
      )
        email = find_email_by_message_id(message_id)
        return unless email

        create_event(email, "delivered", timestamp, event_data)
      end

      def log_email_bounce(
        message_id,
        bounce_type,
        timestamp = Time.current,
        error_message = nil
      )
        email = find_email_by_message_id(message_id)
        return unless email

        event_data = {
          bounce_type: bounce_type,
          error_message: error_message,
        }.compact

        create_event(email, "bounce", timestamp, event_data)
      end

      def log_email_complaint(
        message_id,
        timestamp = Time.current,
        feedback_type = nil
      )
        email = find_email_by_message_id(message_id)
        return unless email

        event_data = { feedback_type: feedback_type }.compact
        create_event(email, "complaint", timestamp, event_data)
      end

      def log_email_open(
        message_id,
        timestamp = Time.current,
        user_agent = nil,
        ip = nil
      )
        email = find_email_by_message_id(message_id)
        return unless email

        event_data = { user_agent: user_agent, ip: ip }.compact

        create_event(email, "open", timestamp, event_data)
      end

      def log_email_click(
        message_id,
        url,
        timestamp = Time.current,
        user_agent = nil
      )
        email = find_email_by_message_id(message_id)
        return unless email

        event_data = { url: url, user_agent: user_agent }.compact

        create_event(email, "click", timestamp, event_data)
      end

      def log_email_suppressed(mail, user = nil)
        new(mail, user).log_suppressed
      end

      def find_email_by_message_id(message_id)
        ::Email.find_by(message_id: message_id)
      end

      def create_event(
        email,
        event_type,
        timestamp = Time.current,
        event_data = {}
      )
        email.email_events.create!(
          event_type: event_type,
          event_data: event_data,
          user: email.user,
          created_at: timestamp,
        )
      end
    end

    attr_reader :mail, :user

    def initialize(mail, user = nil)
      @mail = mail
      @user = user
    end

    def log_attempt
      email = create_email
      create_event(email, "pending")
      email
    end

    def log_sent(message_id)
      email = ::Email.find_by(message_id: message_id)

      if email
        unless email.email_events.exists?(event_type: "sent")
          create_event(email, "sent")
        end
        return email
      end

      email =
        ::Email.find_by(
          recipient: extract_recipient,
          mailer_class: extract_mailer_class,
          mailer_method: extract_mailer_method,
          message_id: nil,
        ) || create_email

      email.update!(message_id: message_id) if email.message_id.blank?

      unless email.email_events.exists?(event_type: "sent")
        create_event(email, "sent")
      end

      email
    end

    def log_suppressed
      email = create_email
      create_event(email, "suppressed")
      email
    end

    private

    def create_email
      duplicate =
        ::Email.where(
          recipient: extract_recipient,
          mailer_class: extract_mailer_class,
          mailer_method: extract_mailer_method,
          user: user,
          created_at: 5.minutes.ago..Time.current,
        ).first

      return duplicate if duplicate

      ::Email.create!(
        recipient: extract_recipient,
        subject: extract_subject,
        mailer_class: extract_mailer_class,
        mailer_method: extract_mailer_method,
        metadata: extract_metadata,
        user: user,
      )
    end

    def create_event(email, event_type, timestamp = Time.current)
      email.email_events.create!(
        event_type: event_type,
        user: user,
        created_at: timestamp,
      )
    end

    def extract_recipient
      recipients = mail.to
      recipients.is_a?(Array) ? recipients.first : recipients
    end

    def extract_subject
      mail.subject.to_s.truncate(255)
    end

    def extract_mailer_class
      header_value(mail["X-Mailer-Class"]) || "UnknownMailer"
    end

    def extract_mailer_method
      header_value(mail["X-Mailer-Method"]) || "unknown_method"
    end

    def extract_metadata
      metadata = {
        from: mail.from,
        cc: mail.cc,
        bcc: mail.bcc,
        reply_to: mail.reply_to,
        content_type: mail.content_type,
        charset: mail.charset,
        headers: extract_custom_headers,
      }

      if (args_header = header_value(mail["X-Mailer-Arguments"]))
        metadata[:mailer_arguments] = deserialize_arguments(args_header)
      end

      metadata
    end

    def extract_custom_headers
      custom_headers = {}

      mail.header_fields.each do |field|
        next unless field.name.start_with?("X-")
        custom_headers[field.name] = field.value
      end

      custom_headers
    end

    def deserialize_arguments(header_value)
      JSON.parse(header_value)
    rescue JSON::ParserError
      header_value
    end

    def header_value(field)
      return if field.nil?

      if field.respond_to?(:value)
        field.value
      elsif field.is_a?(Array)
        header_value(field.first)
      else
        field.to_s
      end
    end
  end
end
