# frozen_string_literal: true

class EmailEvent < ApplicationRecord
  include Sesame::Models::EmailEvent

  # Customize associations if needed
  # belongs_to :email, class_name: "Email"
  # belongs_to :user, class_name: "User", optional: true
end
