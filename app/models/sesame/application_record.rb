# frozen_string_literal: true

module Sesame
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end
