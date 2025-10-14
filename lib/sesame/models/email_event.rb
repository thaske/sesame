# frozen_string_literal: true

module Sesame
  module Models
    module EmailEvent
      extend ActiveSupport::Concern

      EVENT_TYPES = %w[
        pending
        sent
        delivered
        bounce
        complaint
        open
        click
        reject
        spam
        failed
        suppressed
      ].freeze

      included do
        belongs_to :email, class_name: "Email"
        belongs_to :user, class_name: "User", optional: true

        validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }

        scope :recent, -> { order(created_at: :desc) }
        scope :by_type, ->(type) { where(event_type: type) }
        scope :bounced, -> { where(event_type: "bounce") }
        scope :delivered, -> { where(event_type: "delivered") }
        scope :failed, -> { where(event_type: %w[bounce complaint failed]) }
      end

      class_methods do
        def ransackable_scopes(_auth_object = nil)
          %i[recent delivered bounced failed]
        end
      end

      def delivered?
        event_type == "delivered"
      end

      def bounced?
        event_type == "bounce"
      end

      def failed?
        %w[bounce complaint failed].include?(event_type)
      end

      def sent?
        event_type == "sent"
      end

      def pending?
        event_type == "pending"
      end

      def display_event
        case event_type
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
        when "open"
          "Opened"
        when "click"
          "Clicked"
        else
          event_type.titleize
        end
      end

      def error_message
        event_data&.dig("error_message") || event_data&.dig("reason")
      end

      def bounce_type
        event_data&.dig("bounce_type")
      end

      def event_details
        return {} unless event_data.present?

        case event_type
        when "bounce"
          { bounce_type: bounce_type, error: error_message }
        when "complaint"
          { feedback_type: event_data["feedback_type"] }
        when "open"
          { user_agent: event_data["user_agent"], ip: event_data["ip"] }
        when "click"
          { url: event_data["url"], user_agent: event_data["user_agent"] }
        else
          event_data
        end
      end
    end
  end
end
