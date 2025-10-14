# frozen_string_literal: true

require "rails_helper"

RSpec.describe Sesame::SnsSubscriber do
  describe "#confirm" do
    let(:subscribe_url) do
      "https://sns.us-east-1.amazonaws.com/subscribe?token=abc123"
    end
    let(:subscriber) { described_class.new(subscribe_url) }

    it "confirms subscription successfully" do
      stub_request(:get, subscribe_url).to_return(status: 200, body: "OK")

      expect(subscriber.confirm).to be true
    end

    it "returns false when subscription confirmation fails" do
      stub_request(:get, subscribe_url).to_raise(StandardError.new("Network error"))

      expect(subscriber.confirm).to be false
    end

    it "logs success message" do
      stub_request(:get, subscribe_url).to_return(status: 200, body: "OK")

      expect(Rails.logger).to receive(:info).with("SNS subscription confirmed")
      subscriber.confirm
    end

    it "logs error message on failure" do
      stub_request(:get, subscribe_url).to_raise(StandardError.new("Network error"))

      expect(Rails.logger).to receive(:error).with(
        "Failed to confirm SNS subscription: Network error",
      )
      subscriber.confirm
    end
  end
end
