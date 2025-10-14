# frozen_string_literal: true

require "rails_helper"

RSpec.describe Sesame::SnsVerifier do
  let(:valid_message) do
    {
      "Type" => "Notification",
      "MessageId" => "123",
      "TopicArn" => "arn:aws:sns:us-east-1:123:test",
      "Subject" => "Test",
      "Message" => "Test message",
      "Timestamp" => "2024-01-01T00:00:00.000Z",
      "SignatureVersion" => "1",
      "Signature" => Base64.encode64("fake-signature"),
      "SigningCertURL" =>
        "https://sns.us-east-1.amazonaws.com/cert.pem",
    }
  end

  describe "#verify" do
    context "in test environment" do
      it "returns true without verification" do
        verifier = described_class.new(valid_message)
        expect(verifier.verify).to be true
      end
    end

    context "in production environment" do
      before do
        allow(Rails.env).to receive(:test?).and_return(false)
      end

      it "returns false for invalid signature version" do
        message = valid_message.merge("SignatureVersion" => "2")
        verifier = described_class.new(message)
        expect(verifier.verify).to be false
      end

      it "returns false for invalid cert URL" do
        message =
          valid_message.merge("SigningCertURL" => "http://evil.com/cert.pem")
        verifier = described_class.new(message)
        expect(verifier.verify).to be false
      end

      it "returns false when certificate fetch fails" do
        verifier = described_class.new(valid_message)
        allow(verifier).to receive(:fetch_certificate).and_return(nil)
        expect(verifier.verify).to be false
      end

      it "verifies valid signature successfully" do
        cert = instance_double(OpenSSL::X509::Certificate)
        public_key = instance_double(OpenSSL::PKey::RSA)

        allow_any_instance_of(described_class).to receive(
          :fetch_certificate,
        ).and_return(cert)
        allow(cert).to receive(:public_key).and_return(public_key)
        allow(public_key).to receive(:verify).and_return(true)

        verifier = described_class.new(valid_message)
        expect(verifier.verify).to be true
      end

      it "returns false for invalid signature" do
        cert = instance_double(OpenSSL::X509::Certificate)
        public_key = instance_double(OpenSSL::PKey::RSA)

        allow_any_instance_of(described_class).to receive(
          :fetch_certificate,
        ).and_return(cert)
        allow(cert).to receive(:public_key).and_return(public_key)
        allow(public_key).to receive(:verify).and_return(false)

        verifier = described_class.new(valid_message)
        expect(verifier.verify).to be false
      end

      it "returns false when verification raises an error" do
        allow_any_instance_of(described_class).to receive(
          :fetch_certificate,
        ).and_raise(StandardError, "Network error")

        verifier = described_class.new(valid_message)
        expect(verifier.verify).to be false
      end
    end
  end

  describe "#valid_cert_url?" do
    let(:verifier) { described_class.new(valid_message) }

    it "accepts valid SNS certificate URLs" do
      valid_urls = [
        "https://sns.amazonaws.com/cert.pem",
        "https://sns.us-east-1.amazonaws.com/cert.pem",
        "https://sns.eu-west-1.amazonaws.com/cert.pem",
      ]

      valid_urls.each do |url|
        expect(verifier.send(:valid_cert_url?, url)).to be true
      end
    end

    it "rejects invalid certificate URLs" do
      invalid_urls = [
        "http://sns.amazonaws.com/cert.pem", # HTTP instead of HTTPS
        "https://evil.com/cert.pem", # Wrong domain
        "https://sns.evil.com/cert.pem", # Wrong subdomain
        "https://amazonaws.com/cert.pem", # Missing sns subdomain
        "not-a-url", # Invalid URI
      ]

      invalid_urls.each do |url|
        expect(verifier.send(:valid_cert_url?, url)).to be false
      end
    end
  end

  describe "#build_signing_string" do
    let(:verifier) { described_class.new(valid_message) }

    it "builds correct signing string for Notification type" do
      message = {
        "Type" => "Notification",
        "MessageId" => "123",
        "TopicArn" => "arn:test",
        "Message" => "Test",
        "Timestamp" => "2024-01-01T00:00:00Z",
      }

      signing_string = verifier.send(:build_signing_string, message)

      expect(signing_string).to include("Message\nTest\n")
      expect(signing_string).to include("MessageId\n123\n")
      expect(signing_string).to include("Timestamp\n2024-01-01T00:00:00Z\n")
      expect(signing_string).not_to include("SubscribeURL")
    end

    it "builds correct signing string for SubscriptionConfirmation type" do
      message = {
        "Type" => "SubscriptionConfirmation",
        "MessageId" => "123",
        "TopicArn" => "arn:test",
        "Message" => "Test",
        "Timestamp" => "2024-01-01T00:00:00Z",
        "Token" => "token123",
        "SubscribeURL" => "https://sns.amazonaws.com/subscribe",
      }

      signing_string = verifier.send(:build_signing_string, message)

      expect(signing_string).to include(
        "SubscribeURL\nhttps://sns.amazonaws.com/subscribe\n",
      )
      expect(signing_string).to include("Token\ntoken123\n")
    end

    it "excludes fields that are not present" do
      message = { "Type" => "Notification", "MessageId" => "123" }

      signing_string = verifier.send(:build_signing_string, message)

      expect(signing_string).to eq("MessageId\n123\nType\nNotification\n")
    end
  end
end
