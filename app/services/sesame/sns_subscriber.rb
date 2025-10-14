# frozen_string_literal: true

require "net/http"

module Sesame
  class SnsSubscriber
    def initialize(subscribe_url)
      @subscribe_url = subscribe_url
    end

    def confirm
      uri = URI.parse(@subscribe_url)
      Net::HTTP.get(uri)
      Rails.logger.info("SNS subscription confirmed")
      true
    rescue StandardError => e
      Rails.logger.error("Failed to confirm SNS subscription: #{e.message}")
      false
    end
  end
end
