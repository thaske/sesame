# frozen_string_literal: true

FactoryBot.define do
  factory :email do
    recipient { "test@example.com" }
    subject { "Test Email" }
    mailer_class { "TestMailer" }
    mailer_method { "test_email" }
    message_id { SecureRandom.uuid }
    metadata { {} }
    user { nil }
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
