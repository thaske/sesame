# frozen_string_literal: true

module Sesame
  class Configuration
    attr_accessor :preview_resolver, :from_domain

    def initialize
      @preview_resolver = nil
      @from_domain = nil
    end
  end
end
