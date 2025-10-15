# frozen_string_literal: true

module Sesame
  class Configuration
    attr_accessor :preview_resolver, :from_domain, :auto_configure_rails_admin

    def initialize
      @preview_resolver = nil
      @from_domain = nil
      @auto_configure_rails_admin = true
    end
  end
end
