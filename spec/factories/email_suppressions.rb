# frozen_string_literal: true

FactoryBot.define do
  factory :email_suppression do
    sequence(:email) { |n| "suppressed#{n}@example.com" }
    suppression_type { "bounce" }
    reason { "permanent" }
    message_id { "message-#{SecureRandom.hex(8)}" }
    feedback_id { "feedback-#{SecureRandom.hex(8)}" }
    source_ip { "127.0.0.1" }
    source_arn { "arn:aws:ses:us-east-1:123456789:identity/example.com" }
    raw_message { { "test" => "data" }.to_json }
    suppressed_at { Time.current }

    trait :bounce do
      suppression_type { "bounce" }
      reason { "permanent" }
    end

    trait :transient_bounce do
      suppression_type { "bounce" }
      reason { "transient" }
    end

    trait :complaint do
      suppression_type { "complaint" }
      reason { "abuse" }
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
