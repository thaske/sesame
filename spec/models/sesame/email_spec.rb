# frozen_string_literal: true

require "rails_helper"

RSpec.describe Email, type: :model do
  describe "associations" do
    it { should belong_to(:user).optional }
    it { should have_many(:email_events).dependent(:destroy) }
  end

  describe "validations" do
    it { should validate_presence_of(:recipient) }
    it { should validate_presence_of(:mailer_class) }
    it { should validate_presence_of(:mailer_method) }
    it { should allow_value("test@example.com").for(:recipient) }
    it { should_not allow_value("invalid-email").for(:recipient) }

    context "with message_id uniqueness" do
      let!(:existing_email) { create(:email, message_id: "unique-123") }

      it "validates uniqueness of message_id" do
        new_email = build(:email, message_id: "unique-123")
        expect(new_email).not_to be_valid
        expect(new_email.errors[:message_id]).to include(
          "has already been taken",
        )
      end

      it "allows nil message_id" do
        email = build(:email, message_id: nil)
        expect(email).to be_valid
      end
    end
  end

  describe "scopes" do
    let!(:email1) do
      create(
        :email,
        recipient: "user1@example.com",
        mailer_class: "UserMailer",
        mailer_method: "welcome",
      )
    end
    let!(:email2) do
      create(
        :email,
        recipient: "user2@example.com",
        mailer_class: "NotificationMailer",
        mailer_method: "alert",
      )
    end

    describe ".for_recipient" do
      it "filters by recipient email" do
        expect(Email.for_recipient("user1@example.com")).to include(email1)
        expect(Email.for_recipient("user1@example.com")).not_to include(email2)
      end
    end

    describe ".for_mailer" do
      it "filters by mailer class" do
        expect(Email.for_mailer("UserMailer")).to include(email1)
        expect(Email.for_mailer("UserMailer")).not_to include(email2)
      end

      it "filters by mailer class and method" do
        expect(Email.for_mailer("UserMailer", "welcome")).to include(email1)
        expect(Email.for_mailer("UserMailer", "other")).not_to include(email1)
      end
    end
  end

  describe "instance methods" do
    let(:email) { create(:email) }

    describe "#current_status" do
      it "returns pending when no events exist" do
        expect(email.current_status).to eq("pending")
      end

      it "returns the latest event type" do
        create(:email_event, email: email, event_type: "sent")
        create(:email_event, email: email, event_type: "delivered")

        expect(email.current_status).to eq("delivered")
      end
    end

    describe "#delivered?" do
      it "returns true when email has delivered event" do
        create(:email_event, email: email, event_type: "delivered")
        expect(email.delivered?).to be true
      end

      it "returns false when no delivered event exists" do
        create(:email_event, email: email, event_type: "sent")
        expect(email.delivered?).to be false
      end
    end

    describe "#bounced?" do
      it "returns true when email has bounce event" do
        create(:email_event, email: email, event_type: "bounce")
        expect(email.bounced?).to be true
      end

      it "returns false when no bounce event exists" do
        expect(email.bounced?).to be false
      end
    end

    describe "#failed?" do
      it "returns true for bounce emails" do
        create(:email_event, email: email, event_type: "bounce")
        expect(email.failed?).to be true
      end

      it "returns true for complaint emails" do
        create(:email_event, email: email, event_type: "complaint")
        expect(email.failed?).to be true
      end

      it "returns true for failed emails" do
        create(:email_event, email: email, event_type: "failed")
        expect(email.failed?).to be true
      end

      it "returns false for successful emails" do
        create(:email_event, email: email, event_type: "delivered")
        expect(email.failed?).to be false
      end
    end

    describe "#event_timeline" do
      it "returns events ordered by creation time" do
        event2 = create(:email_event, email: email, event_type: "delivered")
        event1 = create(:email_event, email: email, event_type: "sent")

        timeline = email.event_timeline
        expect(timeline.first).to eq(event2)
        expect(timeline.last).to eq(event1)
      end
    end

    describe "#delivery_time" do
      it "calculates time between sent and delivered events" do
        sent_time = 1.hour.ago
        delivered_time = 30.minutes.ago

        create(
          :email_event,
          email: email,
          event_type: "sent",
          created_at: sent_time,
        )
        create(
          :email_event,
          email: email,
          event_type: "delivered",
          created_at: delivered_time,
        )

        expect(email.delivery_time).to be_within(1.second).of(30.minutes)
      end

      it "returns nil when missing sent or delivered events" do
        create(:email_event, email: email, event_type: "sent")
        expect(email.delivery_time).to be_nil
      end
    end

    describe "#display_status" do
      it "returns user-friendly status names" do
        create(:email_event, email: email, event_type: "bounce")
        expect(email.display_status).to eq("Bounced")
      end
    end
  end
end

# == Schema Information
#
# Table name: emails
#
#  id            :bigint           not null, primary key
#  mailer_class  :string           not null
#  mailer_method :string           not null
#  metadata      :json
#  recipient     :string           not null
#  subject       :string
#  tags          :json
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  message_id    :string
#  user_id       :bigint
#
# Indexes
#
#  index_emails_on_created_at                      (created_at)
#  index_emails_on_mailer_class_and_mailer_method  (mailer_class,mailer_method)
#  index_emails_on_message_id                      (message_id) UNIQUE
#  index_emails_on_recipient                       (recipient)
#  index_emails_on_user_id                         (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => nullify
#
