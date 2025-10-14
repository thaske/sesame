# frozen_string_literal: true

class EmailSuppression < ApplicationRecord
  include Sesame::Models::EmailSuppression

  # All suppression logic is included from the concern
  # No additional configuration needed unless you want to customize
end
