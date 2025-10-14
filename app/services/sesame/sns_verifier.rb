# frozen_string_literal: true

require "net/http"
require "base64"
require "openssl"

module Sesame
  class SnsVerifier
    def initialize(message)
      @message = message
    end

    def verify
      return true if Rails.env.test?

      return false unless @message["SignatureVersion"] == "1"

      signing_cert_url = @message["SigningCertURL"]
      return false unless valid_cert_url?(signing_cert_url)

      cert = fetch_certificate(signing_cert_url)
      return false unless cert

      signature = Base64.decode64(@message["Signature"])
      signing_string = build_signing_string(@message)

      cert.public_key.verify(
        OpenSSL::Digest.new("SHA1"),
        signature,
        signing_string,
      )
    rescue StandardError => e
      Rails.logger.error("SNS signature verification failed: #{e.message}")
      false
    end

    private

    def valid_cert_url?(url)
      uri = URI.parse(url)
      uri.scheme == "https" && uri.host&.end_with?(".amazonaws.com") &&
        (
          uri.host == "sns.amazonaws.com" ||
            uri.host&.match?(/^sns\.[a-z0-9\-]+\.amazonaws\.com$/)
        )
    rescue URI::InvalidURIError
      false
    end

    def fetch_certificate(url)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER

      response = http.get(uri.request_uri)
      return unless response.code == "200"

      OpenSSL::X509::Certificate.new(response.body)
    rescue StandardError => e
      Rails.logger.error("Failed to fetch SNS certificate: #{e.message}")
      nil
    end

    def build_signing_string(message)
      fields =
        if message["Type"] == "Notification"
          %w[Message MessageId Subject Timestamp TopicArn Type]
        else
          %w[Message MessageId SubscribeURL Timestamp Token TopicArn Type]
        end

      fields
        .filter_map do |field|
          "#{field}\n#{message[field]}\n" if message[field]
        end
        .join
    end
  end
end
