# frozen_string_literal: true

require "rails_helper"

RSpec.describe EmailSuppression, type: :model do
  describe "validations" do
    it { should validate_presence_of(:email) }
    it { should validate_presence_of(:suppression_type) }
    it { should validate_presence_of(:reason) }

    it "validates email format" do
      suppression = build(:email_suppression, email: "invalid-email")
      expect(suppression).not_to be_valid
      expect(suppression.errors[:email]).to include("is invalid")
    end

    it "validates email uniqueness within suppression type" do
      create(
        :email_suppression,
        email: "test@example.com",
        suppression_type: "bounce",
      )

      # Same email, same type - should be invalid
      duplicate =
        build(
          :email_suppression,
          email: "test@example.com",
          suppression_type: "bounce",
        )
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:email]).to include("has already been taken")

      # Same email, different type - should be valid
      complaint =
        build(
          :email_suppression,
          email: "test@example.com",
          suppression_type: "complaint",
          reason: "abuse",
        )
      expect(complaint).to be_valid
    end

    it "validates suppression_type inclusion" do
      suppression = build(:email_suppression, suppression_type: "invalid")
      expect(suppression).not_to be_valid
      expect(suppression.errors[:suppression_type]).to include(
        "is not included in the list",
      )
    end

    it "validates reason matches suppression type" do
      bounce =
        build(:email_suppression, suppression_type: "bounce", reason: "abuse")
      expect(bounce).not_to be_valid
      expect(bounce.errors[:reason]).to include(
        "is not valid for bounce suppression type",
      )

      complaint =
        build(
          :email_suppression,
          suppression_type: "complaint",
          reason: "permanent",
        )
      expect(complaint).not_to be_valid
      expect(complaint.errors[:reason]).to include(
        "is not valid for complaint suppression type",
      )
    end
  end

  describe ".suppressed?" do
    it "returns true for suppressed email" do
      create(:email_suppression, email: "test@example.com")
      expect(EmailSuppression.suppressed?("test@example.com")).to be true
      expect(EmailSuppression.suppressed?("TEST@EXAMPLE.COM")).to be true
    end

    it "returns false for non-suppressed email" do
      expect(EmailSuppression.suppressed?("notfound@example.com")).to be false
    end
  end

  describe ".create_from_sns_bounce" do
    let(:bounce_notification) do
      {
        "bounce" => {
          "bounceType" => "Permanent",
          "bouncedRecipients" => [
            { "emailAddress" => "bounced1@example.com" },
            { "emailAddress" => "BOUNCED2@EXAMPLE.COM" },
          ],
          "feedbackId" => "feedback123",
        },
        "mail" => {
          "messageId" => "message123",
          "sourceIp" => "127.0.0.1",
          "sourceArn" => "arn:aws:ses:us-east-1:123456789:identity/example.com",
        },
      }
    end

    it "creates suppressions for all bounced recipients" do
      expect {
        EmailSuppression.create_from_sns_bounce(bounce_notification)
      }.to change(EmailSuppression, :count).by(2)

      suppression1 = EmailSuppression.find_by(email: "bounced1@example.com")
      expect(suppression1.suppression_type).to eq("bounce")
      expect(suppression1.reason).to eq("permanent")
      expect(suppression1.feedback_id).to eq("feedback123")

      suppression2 = EmailSuppression.find_by(email: "bounced2@example.com")
      expect(suppression2).to be_present
    end

    it "handles existing suppressions without error" do
      create(:email_suppression, email: "bounced1@example.com")

      expect {
        EmailSuppression.create_from_sns_bounce(bounce_notification)
      }.to change(EmailSuppression, :count).by(1)
    end
  end

  describe ".create_from_sns_complaint" do
    let(:complaint_notification) do
      {
        "complaint" => {
          "complaintFeedbackType" => "abuse",
          "complainedRecipients" => [
            { "emailAddress" => "complained@example.com" },
          ],
          "feedbackId" => "feedback456",
        },
        "mail" => {
          "messageId" => "message456",
          "sourceIp" => "127.0.0.1",
          "sourceArn" => "arn:aws:ses:us-east-1:123456789:identity/example.com",
        },
      }
    end

    it "creates suppressions for complained recipients" do
      expect {
        EmailSuppression.create_from_sns_complaint(complaint_notification)
      }.to change(EmailSuppression, :count).by(1)

      suppression = EmailSuppression.find_by(email: "complained@example.com")
      expect(suppression.suppression_type).to eq("complaint")
      expect(suppression.reason).to eq("abuse")
      expect(suppression.feedback_id).to eq("feedback456")
    end
  end

  describe "callbacks" do
    it "sets suppressed_at before validation if not set" do
      suppression = build(:email_suppression, suppressed_at: nil)
      suppression.valid?
      expect(suppression.suppressed_at).to be_present
    end

    it "does not override existing suppressed_at" do
      timestamp = 1.day.ago.change(usec: 0)
      suppression = build(:email_suppression, suppressed_at: timestamp)
      suppression.valid?
      expect(suppression.suppressed_at.to_i).to eq(timestamp.to_i)
    end
  end
end

# == Schema Information
#
# Table name: email_suppressions
#
#  id               :bigint           not null, primary key
#  email            :string           not null
#  raw_message      :text
#  reason           :string           not null
#  source_arn       :string
#  source_ip        :string
#  suppressed_at    :datetime         not null
#  suppression_type :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  feedback_id      :string
#  message_id       :string
#
# Indexes
#
#  index_email_suppressions_on_created_at        (created_at)
#  index_email_suppressions_on_email             (email)
#  index_email_suppressions_on_suppression_type  (suppression_type)
#
