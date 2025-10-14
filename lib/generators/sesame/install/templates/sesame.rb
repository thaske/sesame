# frozen_string_literal: true

Sesame.configure do |config|
  # REQUIRED: Set the from domain for this app
  # Used to verify SNS notifications belong to this app
  # Only notifications from emails ending with this domain will be processed
  config.from_domain = "example.com" # Change this to your domain (e.g., "app1.example.com")

  # Optional: Custom resolver for email preview generation
  # This is useful if your mailers require specific arguments or setup
  # config.preview_resolver = ->(email) do
  #   mailer_class = email.mailer_class.safe_constantize
  #   # Your custom logic to invoke the mailer with correct arguments
  #   mailer_class.public_send(email.mailer_method, ...)
  # end
end
