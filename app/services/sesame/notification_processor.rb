# frozen_string_literal: true

require "json"

module Sesame
  class NotificationProcessor
    def initialize(sns_message)
      @sns_message = sns_message
    end

    def process
      notification = JSON.parse(@sns_message["Message"])
      notification_type =
        notification["notificationType"] || notification["eventType"]

      return unless notification_type.present?

      # Verify this notification belongs to this app by checking the from domain
      unless notification_belongs_to_app?(notification)
        Rails.logger.info("Ignoring SNS notification for different app")
        return
      end

      case notification_type
      when "Bounce"
        process_bounce(notification)
      when "Complaint"
        process_complaint(notification)
      when "Delivery"
        process_delivery(notification)
      when "Send"
        process_send(notification)
      when "Reject"
        process_reject(notification)
      else
        Rails.logger.warn("Unknown SES notification type: #{notification_type}")
      end
    rescue JSON::ParserError => e
      Rails.logger.error("Failed to parse SES notification: #{e.message}")
    end

    private

    def process_bounce(notification)
      message_id = notification.dig("mail", "messageId")
      timestamp = parse_timestamp(notification.dig("bounce", "timestamp"))
      bounce_type = notification.dig("bounce", "bounceType")

      email = find_or_match_email(message_id, notification, "bounce")

      if email
        bounced_recipients =
          notification.dig("bounce", "bouncedRecipients") || []
        bounced_recipients.each do |recipient|
          error_message = "#{bounce_type}: #{recipient["diagnosticCode"]}"
          event_data = {
            bounce_type: bounce_type,
            error_message: error_message,
          }.compact
          create_event_if_not_exists(email, "bounce", timestamp, event_data)
        end
      end

      # Always record the suppression so the recipient stops receiving mail
      ::EmailSuppression.create_from_sns_bounce(notification)
    end

    def process_complaint(notification)
      message_id = notification.dig("mail", "messageId")
      timestamp = parse_timestamp(notification.dig("complaint", "timestamp"))
      feedback_type = notification.dig("complaint", "feedbackType")

      email = find_or_match_email(message_id, notification, "complaint")

      if email
        create_event_if_not_exists(
          email,
          "complaint",
          timestamp,
          { feedback_type: feedback_type }.compact,
        )
      end

      # Always record the suppression so the recipient stops receiving mail
      ::EmailSuppression.create_from_sns_complaint(notification)
    end

    def process_delivery(notification)
      message_id = notification.dig("mail", "messageId")
      timestamp = parse_timestamp(notification.dig("delivery", "timestamp"))
      event_data = {
        processing_time_millis:
          notification.dig("delivery", "processingTimeMillis"),
        smtp_response: notification.dig("delivery", "smtpResponse"),
      }.compact

      email = find_or_match_email(message_id, notification, "delivery")
      return unless email

      create_event_if_not_exists(email, "delivered", timestamp, event_data)
    end

    def process_send(notification)
      message_id = notification.dig("mail", "messageId")
      timestamp =
        parse_timestamp(
          notification.dig("mail", "timestamp") ||
            notification.dig("send", "timestamp"),
        )
      return unless message_id

      email = ::Email.find_by(message_id: message_id)

      if email
        create_event_if_not_exists(email, "sent", timestamp)
        return
      end

      recipients = notification.dig("mail", "destination") || []
      recipients.each do |recipient|
        candidate =
          ::Email
            .where(recipient: recipient, message_id: [nil, ""])
            .where("created_at > ?", 10.minutes.ago)
            .order(:created_at)
            .last

        next unless candidate

        candidate.update!(message_id: message_id)
        create_event_if_not_exists(candidate, "sent", timestamp)
        break
      end
    end

    def process_reject(notification)
      message_id = notification.dig("mail", "messageId")
      return unless message_id

      timestamp = parse_timestamp(notification.dig("reject", "timestamp"))
      reject_reason = notification.dig("reject", "reason")

      email = ::Email.find_by(message_id: message_id)
      return unless email

      Sesame::EmailTracker.create_event(
        email,
        "failed",
        timestamp,
        { error_message: reject_reason }.compact,
      )
    end

    def parse_timestamp(timestamp_string)
      return Time.current unless timestamp_string
      Time.parse(timestamp_string)
    rescue ArgumentError
      Time.current
    end

    def find_or_match_email(message_id, notification, event_type)
      email = ::Email.find_by(message_id: message_id)
      return email if email

      recipients = notification.dig("mail", "destination") || []
      recipients.each do |recipient|
        candidate =
          ::Email
            .where(recipient: recipient, message_id: [nil, ""])
            .where("created_at > ?", 10.minutes.ago)
            .order(:created_at)
            .last

        next unless candidate

        candidate.update!(message_id: message_id) if message_id.present?
        return candidate
      end

      Rails.logger.warn(
        "No email match for #{event_type} notification #{message_id}",
      )
      nil
    end

    def create_event_if_not_exists(
      email,
      event_type,
      timestamp,
      event_data = {}
    )
      return if email.email_events.exists?(event_type: event_type)

      Sesame::EmailTracker.create_event(
        email,
        event_type,
        timestamp,
        event_data,
      )
    end

    def notification_belongs_to_app?(notification)
      configured_domain = Sesame.configuration.from_domain

      # If no domain is configured, accept all notifications (legacy behavior)
      return true unless configured_domain.present?

      from_email = notification.dig("mail", "source")
      return false unless from_email.present?

      notification_domain = extract_domain(from_email)
      notification_domain == configured_domain
    end

    def extract_domain(email)
      return unless email.present?
      email.split("@").last&.downcase
    end
  end
end
