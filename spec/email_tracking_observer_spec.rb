# frozen_string_literal: true

require "rails_helper"

RSpec.describe "SES mail tracking interceptor" do
  before { ActionMailer::Base.deliveries.clear }

  it "registers EmailTrackingInterceptor as an ActionMailer interceptor" do
    # Check that the interceptor class is defined and has the required methods
    expect(Sesame::Interceptors::EmailTrackingInterceptor).to respond_to(:delivering_email)
    expect(Sesame::Interceptors::EmailTrackingInterceptor).to respond_to(:delivered_email)

    # Verify it's actually registered in the Mail gem's interceptors
    interceptors = Mail.class_variable_get(:@@delivery_interceptors)
    expect(interceptors).to include(
      Sesame::Interceptors::EmailTrackingInterceptor,
    )
  end

  it "logs sent emails after delivery via the interceptor hook" do
    user = create(:user)

    mailer_class =
      Class.new(ActionMailer::Base) do
        include Sesame::EmailTracking

        default from: "noreply@example.com"

        class << self
          def name
            "Sesame::DummyMailer"
          end
        end

        def welcome
          user = params[:user]
          mail(to: user.email, subject: "Welcome!") do |format|
            format.text { render plain: "Welcome to our service!" }
            format.html { render html: "<p>Welcome to our service!</p>".html_safe }
          end
        end
      end

    stub_const("Sesame::DummyMailer", mailer_class)
    allow(Sesame::EmailTracker).to receive(:log_email_sent)

    mailer_class.with(user: user).welcome.deliver_now
    delivered_mail = ActionMailer::Base.deliveries.last

    expect(Sesame::EmailTracker).to have_received(
      :log_email_sent,
    ).with(delivered_mail, delivered_mail.message_id, user)
  end
end
