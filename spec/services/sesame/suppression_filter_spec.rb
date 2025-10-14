# frozen_string_literal: true

require "rails_helper"

RSpec.describe Sesame::SuppressionFilter do
  describe ".add_suppression" do
    it "creates a suppression record" do
      expect {
        described_class.add_suppression(
          "blocked@example.com",
          type: "bounce",
          reason: "permanent",
          metadata: {
            message_id: "msg-123",
          },
        )
      }.to change(EmailSuppression, :count).by(1)

      suppression = EmailSuppression.last
      expect(suppression.email).to eq("blocked@example.com")
      expect(suppression.suppression_type).to eq("bounce")
      expect(suppression.reason).to eq("permanent")
      expect(suppression.message_id).to eq("msg-123")
    end
  end

  describe ".filter_recipients" do
    it "removes suppressed emails" do
      create(
        :email_suppression,
        email: "skip@example.com",
        suppression_type: "bounce",
        reason: "permanent",
      )

      filtered =
        described_class.filter_recipients(%w[keep@example.com skip@example.com])
      expect(filtered).to contain_exactly("keep@example.com")
    end
  end

  describe ".can_send_to?" do
    it "returns false when suppressed" do
      create(
        :email_suppression,
        email: "skip@example.com",
        suppression_type: "bounce",
        reason: "permanent",
      )
      expect(described_class.can_send_to?("skip@example.com")).to be(false)
      expect(described_class.can_send_to?("other@example.com")).to be(true)
    end
  end
end
