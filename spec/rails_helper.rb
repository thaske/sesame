# frozen_string_literal: true

# This gem is designed to be tested within a parent Rails application context.
#
# To run specs, execute from the parent Rails app directory
# that vendors this gem, for example:
#
#   bundle exec rspec gems/sesame/spec
#
# This ensures the full Rails environment, database, and all dependencies are available.

parent_rails_root = File.expand_path("../../..", __dir__)
parent_spec_dir = File.join(parent_rails_root, "spec")

# Add parent spec dir to load path for spec_helper
$LOAD_PATH.unshift(parent_spec_dir) unless $LOAD_PATH.include?(parent_spec_dir)

# Load parent app's spec_helper and rails_helper
require "spec_helper"

ENV["RAILS_ENV"] ||= "test"
require File.join(parent_rails_root, "config", "environment")
abort("The Rails environment is running in production mode!") if Rails.env.production?

require "rspec/rails"

# Load parent app support files
Rails.root.glob("spec/support/**/*.rb").sort_by(&:to_s).each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.filter_rails_from_backtrace!
end
