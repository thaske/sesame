# frozen_string_literal: true

require "active_support"
require "active_support/core_ext/module/attribute_accessors"
require "sesame/version"
require "sesame/configuration"
require "sesame/models/email"
require "sesame/models/email_event"
require "sesame/models/email_suppression"
require "sesame/rails_admin/helpers"
require "sesame/rails_admin/fields/email_preview"
require "sesame/engine"
require "sesame/railtie" if defined?(Rails::Railtie)

module Sesame
  mattr_accessor :configuration, default: Configuration.new

  class << self
    def configure
      yield(configuration)
    end
  end
end
