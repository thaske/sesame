# frozen_string_literal: true

module Sesame
  module Models
    module EmailSuppression
      extend ActiveSupport::Concern

      SUPPRESSION_TYPES = %w[bounce complaint].freeze
      BOUNCE_REASONS = %w[permanent transient undetermined].freeze
      COMPLAINT_REASONS = %w[
        abuse
        auth-failure
        fraud
        not-spam
        other
        virus
      ].freeze

      included do
        validates :email,
                  presence: true,
                  uniqueness: {
                    scope: :suppression_type,
                  },
                  format: {
                    with: URI::MailTo::EMAIL_REGEXP,
                  }
        validates :suppression_type,
                  presence: true,
                  inclusion: {
                    in: SUPPRESSION_TYPES,
                  }
        validates :reason, presence: true
        validate :reason_matches_suppression_type
        validate :suppressed_at_not_in_future

        before_validation :set_suppressed_at
        before_validation :normalize_email_attribute

        scope :bounces, -> { where(suppression_type: "bounce") }
        scope :complaints, -> { where(suppression_type: "complaint") }
        scope :permanent_bounces, -> { bounces.where(reason: "permanent") }
      end

      class_methods do
        def suppressed?(email)
          where(email: normalize_email(email)).exists?
        end

        def create_from_sns_bounce(notification)
          bounce_type = notification.dig("bounce", "bounceType")&.downcase
          recipients = notification.dig("bounce", "bouncedRecipients") || []

          recipients.map do |recipient|
            email = normalize_email(recipient["emailAddress"])

            create_with(
              reason: bounce_type || "undetermined",
              message_id: notification.dig("mail", "messageId"),
              feedback_id: notification.dig("bounce", "feedbackId"),
              source_ip: notification.dig("mail", "sourceIp"),
              source_arn: notification.dig("mail", "sourceArn"),
              raw_message: notification.to_json,
              suppressed_at: Time.current,
            ).find_or_create_by(email: email, suppression_type: "bounce")
          rescue ActiveRecord::RecordNotUnique
            find_by(email: email, suppression_type: "bounce")
          end
        end

        def create_from_sns_complaint(notification)
          complaint_type =
            notification.dig("complaint", "complaintFeedbackType")&.downcase
          recipients =
            notification.dig("complaint", "complainedRecipients") || []

          recipients.map do |recipient|
            email = normalize_email(recipient["emailAddress"])

            create_with(
              reason: complaint_type || "other",
              message_id: notification.dig("mail", "messageId"),
              feedback_id: notification.dig("complaint", "feedbackId"),
              source_ip: notification.dig("mail", "sourceIp"),
              source_arn: notification.dig("mail", "sourceArn"),
              raw_message: notification.to_json,
              suppressed_at: Time.current,
            ).find_or_create_by(email: email, suppression_type: "complaint")
          rescue ActiveRecord::RecordNotUnique
            find_by(email: email, suppression_type: "complaint")
          end
        end

        def normalize_email(email)
          email.to_s.strip.downcase
        end
      end

      private

      def reason_matches_suppression_type
        return unless suppression_type.present? && reason.present?

        valid_reasons =
          suppression_type == "bounce" ? BOUNCE_REASONS : COMPLAINT_REASONS
        unless valid_reasons.include?(reason)
          errors.add(
            :reason,
            "is not valid for #{suppression_type} suppression type",
          )
        end
      end

      def set_suppressed_at
        self.suppressed_at ||= Time.current
      end

      def normalize_email_attribute
        self.email = self.class.normalize_email(email) if email.present?
      end

      def suppressed_at_not_in_future
        return unless suppressed_at.present?
        if suppressed_at > Time.current
          errors.add(:suppressed_at, "cannot be in the future")
        end
      end
    end
  end
end
