# frozen_string_literal: true

module Sesame
  class SnsController < ActionController::Base
    protect_from_forgery with: :null_session

    before_action :parse_sns_message
    before_action :verify_sns_signature

    def handle
      case @sns_message["Type"]
      when "SubscriptionConfirmation"
        Sesame::SnsSubscriber.new(@sns_message["SubscribeURL"]).confirm
        render json: { status: "Subscription confirmed" }, status: :ok
      when "Notification"
        Sesame::NotificationProcessor.new(@sns_message).process
        render json: { status: "Notification processed" }, status: :ok
      else
        render json: { error: "Unknown message type" }, status: :bad_request
      end
    rescue StandardError => e
      Rails.logger.error("SNS webhook error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      render json: {
               error: "Internal server error",
             },
             status: :internal_server_error
    end

    private

    def parse_sns_message
      raw_body = request.body.read
      @sns_message = JSON.parse(raw_body)
    rescue JSON::ParserError => e
      Rails.logger.error("SNS parse error: #{e.message}")
      render json: { error: "Invalid JSON" }, status: :bad_request
    end

    def verify_sns_signature
      return if performed? # Skip if already rendered (e.g., JSON parse error)

      unless Sesame::SnsVerifier.new(@sns_message).verify
        render json: {
                 error: "Invalid SNS message signature",
               },
               status: :unauthorized
      end
    end
  end
end
