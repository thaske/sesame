# Sesame

Sesame is a Rails gem that layers deliverability tooling on Amazon SES. Delivery tracking, automated bounce/complaint suppressions, and mail previews. Use AWS SES with all the features of Postmark, SendGrid, or Mailgun.

**Note:** This gem is designed for experimental and makes opinionated assumptions about model names (`User`, `Email`, `EmailEvent`, `EmailSuppression`) for simplicity.

## Features

- **Tracking**: Track email lifecycle (sent, delivered, bounced, complained, opened, clicked)
- **Suppressions**: Automatically suppress bounced and complained email addresses
- **Multi-App**: Share suppression lists across multiple applications using the same SNS topics
- **SNS Webhooks**: Automatically process SES notifications via SNS webhooks
- **Rails Admin**: Auto-configured admin interface for managing emails and suppressions
- **Email Preview**: View sent emails in Rails Admin

## Installation

Add to your Gemfile:

```ruby
gem "sesame", git: "https://github.com/thaske/sesame.git"
```

Run the installer:

```bash
rails generate sesame:install
rails db:migrate
```

This will create:

- Model files (`Email`, `EmailEvent`, `EmailSuppression`)
- Initializer (`config/initializers/sesame.rb`)
- Mount the SNS webhook endpoint

## Configuration

Edit `config/initializers/sesame.rb`:

```ruby
Sesame.configure do |config|
  # REQUIRED: Set the from domain for this app
  # Used to verify SNS notifications belong to this app
  # Only notifications from emails ending with this domain will be processed
  config.from_domain = "example.com" # e.g., "app1.example.com"

  # Optional: Custom email preview resolver
  # Useful if your mailers require specific arguments
  # config.preview_resolver = ->(email) do
  #   mailer_class = email.mailer_class.safe_constantize
  #   mailer_class.public_send(email.mailer_method, ...)
  # end
end
```

**Note:** The gem expects your models to be named `User`, `Email`, `EmailEvent`, and `EmailSuppression`. These names are hardcoded for simplicity since this is an internal-only gem.

## Multi-App SNS Topic Sharing

When multiple apps share the same SNS topics, the `from_domain` handles notification routing.

### How It Works

```ruby
# App 1: config.from_domain = "app1.example.com"
# App 2: config.from_domain = "app2.example.com"

# Both apps subscribe to the same SNS topics (e.g., shared-ses-bounces, shared-ses-complaints)

# When App 1 sends an email from hello@app1.example.com and it bounces:
# - SNS notification includes mail.source = "hello@app1.example.com"
# - Both apps receive the notification
# - App 1 checks domain (app1.example.com), matches, processes the notification
# - App 2 checks domain (app1.example.com), doesn't match (app2.example.com), ignores notification
# - App 1 creates suppression in its own database

# Suppressions are automatically isolated per app because each has its own database:
EmailSuppression.suppressed?("user@example.com") # Only checks this app's database
```

## Usage

### Checking Suppressions

```ruby
# Check if an email is suppressed
Sesame::SuppressionFilter.can_send_to?("user@example.com")

# Filter recipients (removes suppressed emails)
allowed = Sesame::SuppressionFilter.filter_recipients([
  "user1@example.com",
  "user2@example.com"
])

# Get suppression stats
stats = Sesame::SuppressionFilter.suppression_stats
```

### Manual Suppression Management

```ruby
# Add a suppression
Sesame::SuppressionFilter.add_suppression(
  "user@example.com",
  type: "bounce",
  reason: "permanent"
)

# Remove a suppression
Sesame::SuppressionFilter.remove_suppression("user@example.com")
```

### Accessing Email Data

```ruby
# Find emails
email = Email.find_by(message_id: "...")
emails = Email.for_recipient("user@example.com")
emails = Email.for_mailer("UserMailer", "welcome_email")

# Check status
email.delivered? # => true/false
email.bounced?   # => true/false
email.failed?    # => true/false

# Get timeline
email.event_timeline # => [<EmailEvent>, ...]
email.delivery_time  # => 2.34 seconds
```

## Models

The gem uses ActiveSupport::Concern pattern (like Devise) for flexibility:

```ruby
# app/models/email.rb
class Email < ApplicationRecord
  include Sesame::Models::Email

  # Add custom methods or override associations
  # belongs_to :organization
  # scope :recent_week, -> { where(created_at: 1.week.ago..) }
end
```

## AWS Configuration

### 1. Create SNS Topics

Create two SNS topics (or use existing shared ones):

- `myapp-bounces` (or shared: `shared-ses-bounces`)
- `myapp-complaints` (or shared: `shared-ses-complaints`)

### 2. Configure SES

In AWS SES Console:

1. Go to Configuration Sets → Create configuration set
2. Add SNS event destinations for bounce and complaint events

### 3. Subscribe Webhook

Add HTTPS subscription to both SNS topics:

- **Endpoint**: `https://example.com/webhooks/ses/handle`
- **Protocol**: HTTPS

## Rails Admin

Rails Admin configuration happens automatically! No manual setup needed.

Just visit `/admin` and you'll see the Email, EmailEvent, and EmailSuppression models configured. This includes previews of the individual emails, as well as a log of email events.

## License

Released under the MIT license.
