# frozen_string_literal: true

module Sesame
  module Models
    module Email
      extend ActiveSupport::Concern

      included do
        belongs_to :user, class_name: "User", optional: true

        has_many :email_events,
                 class_name: "EmailEvent",
                 foreign_key: :email_id,
                 dependent: :destroy

        validates :recipient,
                  presence: true,
                  format: {
                    with: URI::MailTo::EMAIL_REGEXP,
                  }
        validates :mailer_class, presence: true
        validates :mailer_method, presence: true
        validates :message_id, uniqueness: true, allow_nil: true

        scope :recent, -> { order(created_at: :desc) }
        scope :for_recipient, ->(email) { where(recipient: email) }
        scope :for_mailer,
              lambda { |mailer_class, method = nil|
                query = where(mailer_class: mailer_class)
                method ? query.where(mailer_method: method) : query
              }
      end

      def current_status
        email_events.order(:created_at).last&.event_type || "pending"
      end

      def delivered?
        email_events.exists?(event_type: "delivered")
      end

      def bounced?
        email_events.exists?(event_type: "bounce")
      end

      def failed?
        email_events.where(event_type: %w[bounce complaint failed]).exists?
      end

      def event_timeline
        email_events.order(:created_at)
      end

      def delivery_time
        sent_event = email_events.find_by(event_type: "sent")
        delivered_event = email_events.find_by(event_type: "delivered")
        return unless sent_event && delivered_event

        delivered_event.created_at - sent_event.created_at
      end

      def display_status
        case current_status
        when "pending"
          "Queued"
        when "sent"
          "Sent"
        when "delivered"
          "Delivered"
        when "bounce"
          "Bounced"
        when "complaint"
          "Complained"
        when "failed"
          "Failed"
        when "suppressed"
          "Suppressed"
        else
          current_status.to_s.titleize
        end
      end
    end
  end
end
