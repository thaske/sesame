# frozen_string_literal: true

class Email < ApplicationRecord
  include Sesame::Models::Email

  # Customize associations if needed
  # has_many :email_events, class_name: "EmailEvent", foreign_key: :email_id, dependent: :destroy
  # belongs_to :user, class_name: "User", optional: true
end
