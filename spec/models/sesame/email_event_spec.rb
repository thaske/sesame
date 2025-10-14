# frozen_string_literal: true

require "rails_helper"

RSpec.describe EmailEvent, type: :model do
  describe "associations" do
    it { should belong_to(:email) }
    it { should belong_to(:user).optional }
  end

  describe "validations" do
    it { should validate_presence_of(:event_type) }
    it do
      should validate_inclusion_of(:event_type).in_array(
               Sesame::Models::EmailEvent::EVENT_TYPES,
             )
    end
  end

  describe "scopes" do
    let(:email) { create(:email) }
    let!(:sent_event) { create(:email_event, email: email, event_type: "sent") }
    let!(:delivered_event) do
      create(:email_event, email: email, event_type: "delivered")
    end
    let!(:bounce_event) do
      create(:email_event, email: email, event_type: "bounce")
    end

    describe ".by_type" do
      it "filters by event type" do
        expect(EmailEvent.by_type("sent")).to include(sent_event)
        expect(EmailEvent.by_type("sent")).not_to include(delivered_event)
      end
    end

    describe ".bounced" do
      it "returns only bounce events" do
        expect(EmailEvent.bounced).to include(bounce_event)
        expect(EmailEvent.bounced).not_to include(sent_event)
      end
    end

    describe ".delivered" do
      it "returns only delivered events" do
        expect(EmailEvent.delivered).to include(delivered_event)
        expect(EmailEvent.delivered).not_to include(sent_event)
      end
    end
  end

  describe "instance methods" do
    let(:email) { create(:email) }

    describe "#delivered?" do
      it "returns true for delivered events" do
        event = create(:email_event, email: email, event_type: "delivered")
        expect(event.delivered?).to be true
      end

      it "returns false for non-delivered events" do
        event = create(:email_event, email: email, event_type: "sent")
        expect(event.delivered?).to be false
      end
    end

    describe "#bounced?" do
      it "returns true for bounce events" do
        event = create(:email_event, email: email, event_type: "bounce")
        expect(event.bounced?).to be true
      end
    end

    describe "#display_event" do
      it "returns user-friendly event names" do
        event = create(:email_event, email: email, event_type: "bounce")
        expect(event.display_event).to eq("Bounced")
      end
    end

    describe "#error_message" do
      it "extracts error message from event_data" do
        event =
          create(
            :email_event,
            email: email,
            event_type: "bounce",
            event_data: {
              "error_message" => "User unknown",
            },
          )
        expect(event.error_message).to eq("User unknown")
      end
    end

    describe "#bounce_type" do
      it "extracts bounce type from event_data" do
        event =
          create(
            :email_event,
            email: email,
            event_type: "bounce",
            event_data: {
              "bounce_type" => "Permanent",
            },
          )
        expect(event.bounce_type).to eq("Permanent")
      end
    end
  end
end

# == Schema Information
#
# Table name: email_events
#
#  id         :bigint           not null, primary key
#  event_data :json
#  event_type :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  email_id   :bigint           not null
#  user_id    :bigint
#
# Indexes
#
#  index_email_events_on_created_at               (created_at)
#  index_email_events_on_email_id                 (email_id)
#  index_email_events_on_email_id_and_created_at  (email_id,created_at)
#  index_email_events_on_email_id_and_event_type  (email_id,event_type)
#  index_email_events_on_event_type               (event_type)
#  index_email_events_on_user_id                  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (email_id => emails.id)
#  fk_rails_...  (user_id => users.id) ON DELETE => nullify
#
