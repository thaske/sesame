# frozen_string_literal: true

require "rails_helper"

RSpec.describe Sesame::NotificationProcessor do
  let(:from_domain) { "example.com" }

  before do
    allow(Sesame.configuration).to receive(:from_domain).and_return(
      from_domain,
    )
  end

  describe "#process" do
    context "with bounce notification" do
      let(:email) { create(:email, message_id: "bounce-msg-123") }
      let(:bounce_notification) do
        {
          "Message" =>
            {
              notificationType: "Bounce",
              mail: {
                messageId: "bounce-msg-123",
                source: "sender@example.com",
                destination: [email.recipient],
              },
              bounce: {
                bounceType: "Permanent",
                timestamp: "2024-01-01T00:00:00.000Z",
                bouncedRecipients: [
                  {
                    emailAddress: email.recipient,
                    diagnosticCode: "550 User not found",
                  },
                ],
              },
            }.to_json,
        }
      end

      it "processes bounce and creates event" do
        processor = described_class.new(bounce_notification)

        expect { processor.process }.to change(EmailEvent, :count).by(1)

        event = email.email_events.last
        expect(event.event_type).to eq("bounce")
        expect(event.event_data["bounce_type"]).to eq("Permanent")
      end

      it "creates email suppression" do
        processor = described_class.new(bounce_notification)

        expect { processor.process }.to change(EmailSuppression, :count).by(1)
      end

      it "does not create duplicate events" do
        create(:email_event, email: email, event_type: "bounce")
        processor = described_class.new(bounce_notification)

        expect { processor.process }.not_to change(EmailEvent, :count)
      end
    end

    context "with complaint notification" do
      let(:email) { create(:email, message_id: "complaint-msg-123") }
      let(:complaint_notification) do
        {
          "Message" =>
            {
              notificationType: "Complaint",
              mail: {
                messageId: "complaint-msg-123",
                source: "sender@example.com",
                destination: [email.recipient],
              },
              complaint: {
                feedbackType: "abuse",
                timestamp: "2024-01-01T00:00:00.000Z",
                complainedRecipients: [{ emailAddress: email.recipient }],
              },
            }.to_json,
        }
      end

      it "processes complaint and creates event" do
        processor = described_class.new(complaint_notification)

        expect { processor.process }.to change(EmailEvent, :count).by(1)

        event = email.email_events.last
        expect(event.event_type).to eq("complaint")
        expect(event.event_data["feedback_type"]).to eq("abuse")
      end

      it "creates email suppression" do
        processor = described_class.new(complaint_notification)

        expect { processor.process }.to change(EmailSuppression, :count).by(1)
      end
    end

    context "with delivery notification" do
      let(:email) { create(:email, message_id: "delivery-msg-123") }
      let(:delivery_notification) do
        {
          "Message" =>
            {
              notificationType: "Delivery",
              mail: {
                messageId: "delivery-msg-123",
                source: "sender@example.com",
                destination: [email.recipient],
              },
              delivery: {
                timestamp: "2024-01-01T00:00:00.000Z",
                processingTimeMillis: 1234,
                smtpResponse: "250 OK",
              },
            }.to_json,
        }
      end

      it "processes delivery and creates event" do
        processor = described_class.new(delivery_notification)

        expect { processor.process }.to change(EmailEvent, :count).by(1)

        event = email.email_events.last
        expect(event.event_type).to eq("delivered")
        expect(event.event_data["processing_time_millis"]).to eq(1234)
        expect(event.event_data["smtp_response"]).to eq("250 OK")
      end

      it "does not create suppression for delivery" do
        processor = described_class.new(delivery_notification)

        expect { processor.process }.not_to change(EmailSuppression, :count)
      end
    end

    context "with send notification" do
      let(:email) { create(:email, message_id: nil, recipient: "test@example.com") }
      let(:send_notification) do
        {
          "Message" =>
            {
              notificationType: "Send",
              mail: {
                messageId: "send-msg-123",
                source: "sender@example.com",
                destination: [email.recipient],
                timestamp: "2024-01-01T00:00:00.000Z",
              },
            }.to_json,
        }
      end

      it "processes send and updates message_id" do
        processor = described_class.new(send_notification)

        expect { processor.process }.to change { email.reload.message_id }.from(
          nil,
        ).to("send-msg-123")
      end

      it "creates sent event" do
        processor = described_class.new(send_notification)

        expect { processor.process }.to change(EmailEvent, :count).by(1)

        event = email.reload.email_events.last
        expect(event.event_type).to eq("sent")
      end

      context "when email already has message_id" do
        let(:email) do
          create(:email, message_id: "send-msg-123", recipient: "test@example.com")
        end

        it "does not update message_id" do
          processor = described_class.new(send_notification)

          expect { processor.process }.not_to(change { email.reload.message_id })
        end
      end
    end

    context "with reject notification" do
      let(:email) { create(:email, message_id: "reject-msg-123") }
      let(:reject_notification) do
        {
          "Message" =>
            {
              notificationType: "Reject",
              mail: {
                messageId: "reject-msg-123",
                source: "sender@example.com",
                destination: [email.recipient],
              },
              reject: {
                timestamp: "2024-01-01T00:00:00.000Z",
                reason: "Blacklisted",
              },
            }.to_json,
        }
      end

      it "processes reject and creates failed event" do
        processor = described_class.new(reject_notification)

        expect { processor.process }.to change(EmailEvent, :count).by(1)

        event = email.email_events.last
        expect(event.event_type).to eq("failed")
        expect(event.event_data["error_message"]).to eq("Blacklisted")
      end
    end

    context "with unknown notification type" do
      let(:unknown_notification) do
        {
          "Message" =>
            {
              notificationType: "Unknown",
              mail: {
                messageId: "unknown-msg-123",
                source: "sender@example.com",
              },
            }.to_json,
        }
      end

      it "logs warning for unknown type" do
        processor = described_class.new(unknown_notification)

        expect(Rails.logger).to receive(:warn).with(
          "Unknown SES notification type: Unknown",
        )
        processor.process
      end
    end

    context "with domain filtering" do
      let(:email) { create(:email, message_id: "msg-123") }

      context "when notification is from configured domain" do
        let(:notification) do
          {
            "Message" =>
              {
                notificationType: "Delivery",
                mail: {
                  messageId: "msg-123",
                  source: "sender@example.com",
                  destination: [email.recipient],
                },
                delivery: {
                  timestamp: "2024-01-01T00:00:00.000Z",
                },
              }.to_json,
          }
        end

        it "processes the notification" do
          processor = described_class.new(notification)

          expect { processor.process }.to change(EmailEvent, :count).by(1)
        end
      end

      context "when notification is from different domain" do
        let(:notification) do
          {
            "Message" =>
              {
                notificationType: "Delivery",
                mail: {
                  messageId: "msg-123",
                  source: "sender@different.com",
                  destination: [email.recipient],
                },
                delivery: {
                  timestamp: "2024-01-01T00:00:00.000Z",
                },
              }.to_json,
          }
        end

        it "ignores the notification" do
          processor = described_class.new(notification)

          expect { processor.process }.not_to change(EmailEvent, :count)
        end

        it "logs that notification was ignored" do
          processor = described_class.new(notification)

          expect(Rails.logger).to receive(:info).with(
            "Ignoring SNS notification for different app",
          )
          processor.process
        end
      end

      context "when no domain is configured" do
        before do
          allow(Sesame.configuration).to receive(:from_domain).and_return(
            nil,
          )
        end

        let(:notification) do
          {
            "Message" =>
              {
                notificationType: "Delivery",
                mail: {
                  messageId: "msg-123",
                  source: "sender@any-domain.com",
                  destination: [email.recipient],
                },
                delivery: {
                  timestamp: "2024-01-01T00:00:00.000Z",
                },
              }.to_json,
          }
        end

        it "accepts all notifications (legacy behavior)" do
          processor = described_class.new(notification)

          expect { processor.process }.to change(EmailEvent, :count).by(1)
        end
      end
    end


    context "with email matching by recipient" do
      let(:email) do
        create(:email, message_id: nil, recipient: "test@example.com")
      end
      let(:notification) do
        {
          "Message" =>
            {
              notificationType: "Delivery",
              mail: {
                messageId: "new-msg-123",
                source: "sender@example.com",
                destination: [email.recipient],
              },
              delivery: {
                timestamp: "2024-01-01T00:00:00.000Z",
              },
            }.to_json,
        }
      end

      it "matches email by recipient when message_id is nil" do
        processor = described_class.new(notification)

        expect { processor.process }.to change { email.reload.message_id }.from(
          nil,
        ).to("new-msg-123")
      end

      it "creates event for matched email" do
        processor = described_class.new(notification)

        expect { processor.process }.to change(EmailEvent, :count).by(1)
      end

      context "when email is too old" do
        let(:email) do
          create(
            :email,
            message_id: nil,
            recipient: "test@example.com",
            created_at: 11.minutes.ago,
          )
        end

        it "does not match old emails" do
          processor = described_class.new(notification)

          expect { processor.process }.not_to(change { email.reload.message_id })
        end

        it "logs warning about no match" do
          processor = described_class.new(notification)

          expect(Rails.logger).to receive(:warn).with(
            /No email match for delivery notification/,
          )
          processor.process
        end
      end
    end
  end
end
