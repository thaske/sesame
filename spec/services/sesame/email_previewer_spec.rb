# frozen_string_literal: true

require "rails_helper"

RSpec.describe Sesame::EmailPreviewer do
  around do |example|
    original_resolver = Sesame.configuration.preview_resolver
    example.run
  ensure
    Sesame.configure do |config|
      config.preview_resolver = original_resolver
    end
  end

  it "uses the preview resolver to render html" do
    email =
      create(
        :email,
        metadata: {
        },
        mailer_class: "ApplicationMailer",
        mailer_method: "dummy",
      )
    mail_message =
      Mail.new.tap do |message|
        message.content_type = "text/html"
        message.body = "<p>Hello</p>"
      end

    Sesame.configure do |config|
      config.preview_resolver = ->(_email) { mail_message }
    end

    expect(described_class.generate_preview(email)).to eq("<p>Hello</p>")
  end
end
