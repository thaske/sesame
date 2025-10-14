# frozen_string_literal: true

require "rails_helper"

RSpec.describe Sesame::SnsController, type: :controller do
  routes { Sesame::Engine.routes }

  let(:valid_sns_message) do
    {
      "Type" => "Notification",
      "MessageId" => "123",
      "TopicArn" => "arn:aws:sns:us-east-1:123:test",
      "Message" => '{"notificationType":"Send","mail":{"messageId":"msg-123"}}',
      "Timestamp" => "2024-01-01T00:00:00.000Z",
      "SignatureVersion" => "1",
      "Signature" => Base64.encode64("fake-signature"),
      "SigningCertURL" =>
        "https://sns.us-east-1.amazonaws.com/cert.pem",
    }
  end

  describe "POST #handle" do
    context "with invalid JSON" do
      it "returns 400 bad request" do
        post :handle, body: "invalid json"

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)).to eq({ "error" => "Invalid JSON" })
      end

      it "logs parse error" do
        expect(Rails.logger).to receive(:error).with(/SNS parse error/)

        post :handle, body: "invalid json"
      end
    end

    context "with invalid signature" do
      before do
        allow_any_instance_of(Sesame::SnsVerifier).to receive(
          :verify,
        ).and_return(false)
      end

      it "returns 401 unauthorized" do
        post :handle, body: valid_sns_message.to_json

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)).to eq(
          { "error" => "Invalid SNS message signature" },
        )
      end
    end

    context "with valid SubscriptionConfirmation message" do
      let(:subscription_message) do
        valid_sns_message.merge(
          "Type" => "SubscriptionConfirmation",
          "SubscribeURL" => "https://sns.amazonaws.com/subscribe?token=abc",
        )
      end

      before do
        allow_any_instance_of(Sesame::SnsVerifier).to receive(
          :verify,
        ).and_return(true)
      end

      it "delegates to SnsSubscriber service" do
        subscriber = instance_double(Sesame::SnsSubscriber)
        allow(Sesame::SnsSubscriber).to receive(:new).with(
          "https://sns.amazonaws.com/subscribe?token=abc",
        ).and_return(subscriber)
        expect(subscriber).to receive(:confirm)

        post :handle, body: subscription_message.to_json
      end

      it "returns 200 success" do
        allow_any_instance_of(Sesame::SnsSubscriber).to receive(:confirm)

        post :handle, body: subscription_message.to_json

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq(
          { "status" => "Subscription confirmed" },
        )
      end
    end

    context "with valid Notification message" do
      before do
        allow_any_instance_of(Sesame::SnsVerifier).to receive(
          :verify,
        ).and_return(true)
      end

      it "delegates to NotificationProcessor service" do
        processor = instance_double(Sesame::NotificationProcessor)
        allow(Sesame::NotificationProcessor).to receive(:new).with(
          valid_sns_message,
        ).and_return(processor)
        expect(processor).to receive(:process)

        post :handle, body: valid_sns_message.to_json
      end

      it "returns 200 success" do
        allow_any_instance_of(Sesame::NotificationProcessor).to receive(
          :process,
        )

        post :handle, body: valid_sns_message.to_json

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq(
          { "status" => "Notification processed" },
        )
      end
    end

    context "with unknown message type" do
      let(:unknown_message) { valid_sns_message.merge("Type" => "Unknown") }

      before do
        allow_any_instance_of(Sesame::SnsVerifier).to receive(
          :verify,
        ).and_return(true)
      end

      it "returns 400 bad request" do
        post :handle, body: unknown_message.to_json

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)).to eq(
          { "error" => "Unknown message type" },
        )
      end
    end

    context "when an unexpected error occurs" do
      before do
        allow_any_instance_of(Sesame::SnsVerifier).to receive(
          :verify,
        ).and_return(true)
        allow_any_instance_of(Sesame::NotificationProcessor).to receive(
          :process,
        ).and_raise(StandardError.new("Unexpected error"))
      end

      it "returns 500 internal server error" do
        post :handle, body: valid_sns_message.to_json

        expect(response).to have_http_status(:internal_server_error)
        expect(JSON.parse(response.body)).to eq(
          { "error" => "Internal server error" },
        )
      end

      it "logs the error" do
        expect(Rails.logger).to receive(:error).with(/SNS webhook error/)
        expect(Rails.logger).to receive(:error).with(
          kind_of(String),
        ) # backtrace

        post :handle, body: valid_sns_message.to_json
      end
    end

    context "CSRF protection" do
      it "uses null_session strategy" do
        expect(
          controller.class.forgery_protection_strategy,
        ).to eq(
          ActionController::RequestForgeryProtection::ProtectionMethods::NullSession,
        )
      end
    end
  end
end
