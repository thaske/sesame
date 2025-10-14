# frozen_string_literal: true

require "rails/generators"

module Sesame
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)
      desc "Creates models, initializer and provides setup guidance for Sesame."

      def self.next_migration_number(dirname)
        next_migration_number = current_migration_number(dirname) + 1
        ActiveRecord::Migration.next_migration_number(next_migration_number)
      end

      def copy_initializer
        template "sesame.rb",
                 "config/initializers/sesame.rb"
      end

      def create_models
        template "email_model.rb", "app/models/email.rb"
        template "email_event_model.rb", "app/models/email_event.rb"
        template "email_suppression_model.rb", "app/models/email_suppression.rb"
      end

      def create_migration
        migration_template "create_sesame_tables.rb.tt",
                          "db/migrate/create_sesame_tables.rb"
      end

      def mount_engine
        route <<~ROUTE
          mount Sesame::Engine => "/webhooks/ses"
        ROUTE
      end

      def show_instructions
        say <<~INSTRUCTIONS

          Sesame installed!

          Next steps:
            1. Review config/initializers/sesame.rb and set your from_domain.
            2. Run `bin/rails db:migrate` to create email tracking tables.
            3. Adjust the `mount Sesame::Engine` path in config/routes.rb if needed.
            4. Configure Amazon SES to post SNS notifications to /webhooks/ses/handle.
            5. RailsAdmin will auto-configure if present (no manual setup needed).
            6. Use Sesame::SuppressionFilter directly (no wrapper classes needed).
        INSTRUCTIONS
      end
    end
  end
end
