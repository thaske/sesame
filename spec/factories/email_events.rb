# frozen_string_literal: true

FactoryBot.define do
  factory :email_event do
    email
    user { nil }
    event_type { "sent" }
    event_data { {} }
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
