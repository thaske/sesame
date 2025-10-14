# frozen_string_literal: true

require "rails_helper"

RSpec.describe Sesame::EmailTracker do
  let(:user) { create(:user) }
  let(:mail) do
    Mail.new.tap do |m|
      m.to = [user.email]
      m.subject = "Test"
      m.body = "Hello world"
      m.header["X-Mailer-Class"] = "TestMailer"
      m.header["X-Mailer-Method"] = "test_notification"
    end
  end

  describe ".log_email_attempt" do
    it "creates an email and pending event" do
      expect { described_class.log_email_attempt(mail, user) }.to change(
        Email,
        :count,
      ).by(1).and change(EmailEvent, :count).by(1)

      email = Email.last
      expect(email.recipient).to eq(user.email)
      expect(email.email_events.order(:created_at).last.event_type).to eq(
        "pending",
      )
    end
  end

  describe ".log_email_sent" do
    it "marks an existing email as sent" do
      email = described_class.log_email_attempt(mail, user)

      expect {
        mail.message_id = "test-message-id"
        described_class.log_email_sent(mail, "test-message-id", user)
      }.to change { email.reload.email_events.count }.by(1)

      expect(email.reload.message_id).to eq("test-message-id")
      expect(email.email_events.order(:created_at).last.event_type).to eq(
        "sent",
      )
    end
  end

  describe ".log_email_suppressed" do
    it "records a suppression event" do
      expect { described_class.log_email_suppressed(mail, user) }.to change(
        EmailEvent,
        :count,
      ).by(1)

      event = EmailEvent.last
      expect(event.event_type).to eq("suppressed")
      expect(event.email.recipient).to eq(user.email)
    end
  end
end
