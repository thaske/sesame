# frozen_string_literal: true

require "base64"
require "json"
require "active_support/core_ext/string/output_safety"

module Sesame
  module RailsAdminConfig
    class << self
      # Auto-configure RailsAdmin if it's available
      # This will be called automatically by the railtie
      def setup
        return unless defined?(::RailsAdmin)

        ::RailsAdmin.config do |config|
          configure_email_event(config)
          configure_email(config)
          configure_email_suppression(config)
        end
      end

      def configure_email_suppression(config)
        config.model "EmailSuppression" do
          list do
            field :id
            field :email
            field :suppression_type
            field :reason
            field :suppressed_at
            field :created_at

            sort_by :created_at
          end

          show do
            field :id
            field :email
            field :suppression_type
            field :reason
            field :message_id
            field :feedback_id
            field :source_ip
            field :source_arn
            field :suppressed_at
            field :created_at
            field :updated_at
          end

          edit do
            field :email
            field :suppression_type
            field :reason
          end
        end
      end

      def configure_email_event(config)
        config.model "EmailEvent" do
          list do
            field :id
            field :email do
              searchable true
              sortable true
              filterable true
            end
            field :event_type do
              searchable true
              sortable true
              filterable true
              formatted_value do
                event_type = bindings[:object].event_type
                badge(event_type, bindings[:object].display_event)
              end
            end
            field :recipient do
              searchable false
              sortable false
              formatted_value { bindings[:object].email&.recipient }
            end
            field :subject do
              column_width 200
              searchable false
              sortable false
              formatted_value { bindings[:object].email&.subject }
            end
            field :processing_time do
              label "Processing"
              searchable false
              sortable false
              formatted_value do
                details = bindings[:object].event_details
                if details && details["processingTimeMillis"]
                  "#{details["processingTimeMillis"]}ms"
                elsif details && details["processing_time_ms"]
                  "#{details["processing_time_ms"]}ms"
                else
                  "-"
                end
              end
            end
            field :smtp_response do
              label "SMTP Response"
              column_width 150
              searchable false
              sortable false
              formatted_value do
                details = bindings[:object].event_details
                if details && details["smtpResponse"]
                  response = details["smtpResponse"].to_s
                  response.length > 30 ? "#{response[0..27]}..." : response
                else
                  "-"
                end
              end
            end
            field :bounce_type do
              label "Bounce Type"
              searchable false
              sortable false
              formatted_value do
                if bindings[:object].bounce_type.present?
                  badge("bounce", bindings[:object].bounce_type)
                else
                  "-"
                end
              end
            end
            field :user do
              searchable true
              sortable true
              filterable true
            end
            field :created_at do
              sortable true
              filterable true
            end

            sort_by :created_at

            scopes %i[recent delivered bounced failed]
          end

          show do
            group :event_details do
              label "Event Details"

              field :id

              field :email

              field :event_type do
                formatted_value do
                  event_type = bindings[:object].event_type
                  badge(event_type, bindings[:object].display_event)
                end
              end

              field :user

              field :created_at do
                label "Event Time"
              end
            end

            group :event_data do
              label "Event Data"

              field :processing_metrics do
                label "Processing Metrics"
                formatted_value do
                  details = bindings[:object].event_details
                  if details.present?
                    metrics = []
                    if details["processingTimeMillis"]
                      metrics << "Processing Time: #{details["processingTimeMillis"]}ms"
                    end
                    if details["smtpResponse"]
                      metrics << "SMTP Response: #{details["smtpResponse"]}"
                    end
                    if details["remoteMtaIp"]
                      metrics << "Remote MTA IP: #{details["remoteMtaIp"]}"
                    end
                    if details["reportingMTA"]
                      metrics << "Reporting MTA: #{details["reportingMTA"]}"
                    end
                    if details["recipients"]
                      metrics << "Recipients: #{details["recipients"].join(", ")}"
                    end

                    if metrics.any?
                      style =
                        "background: #f8f9fa; padding: 15px; border-radius: 5px; border-left: 4px solid #007bff;"
                      %(<div style="#{style}">#{metrics.join("<br>").html_safe}</div>).html_safe
                    else
                      "No processing metrics available"
                    end
                  else
                    "No processing metrics available"
                  end
                end
              end

              field :bounce_details do
                label "Bounce/Complaint Details"
                formatted_value do
                  details = []

                  if bindings[:object].bounce_type.present?
                    details << "Bounce Type: #{bindings[:object].bounce_type}"
                  end
                  if bindings[:object].error_message.present?
                    details << "Error Message: #{bindings[:object].error_message}"
                  end

                  event_details = bindings[:object].event_details
                  if event_details.present?
                    if event_details["bounceType"]
                      details << "SES Bounce Type: #{event_details["bounceType"]}"
                    end
                    if event_details["bounceSubType"]
                      details << "SES Bounce SubType: #{event_details["bounceSubType"]}"
                    end
                    if event_details["complaintFeedbackType"]
                      details << "Complaint Feedback Type: #{event_details["complaintFeedbackType"]}"
                    end
                  end

                  if details.any?
                    style =
                      "background: #fff3cd; padding: 15px; border-radius: 5px; border-left: 4px solid #ffc107;"
                    %(<div style="#{style}">#{details.join("<br>").html_safe}</div>).html_safe
                  else
                    "No bounce/complaint details"
                  end
                end

                visible do
                  bindings[:object].event_type.in?(%w[bounce complaint]) ||
                    bindings[:object].bounce_type.present? ||
                    bindings[:object].error_message.present?
                end
              end

              field :event_details do
                label "Raw Event Data"
                formatted_value do
                  details = bindings[:object].event_details
                  if details.any?
                    style =
                      "background: #f5f5f5; padding: 10px; border-radius: 3px; max-height: 400px; overflow-y: auto;"
                    %(<pre style="#{style}">#{JSON.pretty_generate(details)}</pre>).html_safe
                  else
                    "No additional data"
                  end
                end
              end
            end

            group :email_info do
              label "Email Information"

              field :recipient do
                formatted_value { bindings[:object].email&.recipient }
              end

              field :subject do
                formatted_value { bindings[:object].email&.subject }
              end

              field :mailer_class do
                formatted_value { bindings[:object].email&.mailer_class }
              end

              field :mailer_method do
                formatted_value { bindings[:object].email&.mailer_method }
              end

              field :message_id do
                formatted_value { bindings[:object].email&.message_id }
              end
            end
          end

          edit do
            field :email
            field :event_type
            field :event_data
          end
        end
      end

      def configure_email(config)
        config.model "Email" do
          list do
            field :id
            field :recipient do
              searchable true
              sortable true
            end
            field :subject do
              column_width 300
              searchable true
              sortable true
            end
            field :mailer_class do
              searchable true
              sortable true
              filterable true
            end
            field :mailer_method do
              searchable true
              sortable true
              filterable true
            end
            field :current_status do
              label "Status"
              searchable false
              sortable false
              filterable false
              formatted_value do
                status = bindings[:object].current_status
                badge(status, bindings[:object].display_status)
              end
            end
            field :user do
              searchable true
              sortable true
              filterable true
            end
            field :created_at do
              sortable true
              filterable true
            end

            sort_by :created_at
          end

          show do
            group :email_details do
              label "Email Details"

              field :id
              field :recipient
              field :subject do
                column_width 400
              end
              field :mailer_class
              field :mailer_method
              field :message_id
              field :user
              field :created_at do
                label "Created"
              end
            end

            group :current_status do
              label "Current Status"

              field :current_status do
                label "Status"
                formatted_value do
                  status = bindings[:object].current_status
                  badge(status, bindings[:object].display_status)
                end
              end

              field :delivery_time do
                label "Delivery Time"
                formatted_value do
                  if bindings[:object].delivery_time
                    "#{bindings[:object].delivery_time.round(2)}s"
                  else
                    "N/A"
                  end
                end
                visible { bindings[:object].delivery_time.present? }
              end
            end

            group :event_timeline do
              label "Event Timeline"
              field :event_timeline_display do
                label ""
                formatted_value do
                  events = bindings[:object].event_timeline
                  if events.any?
                    timeline_html = <<~HTML
                    <table class="table table-condensed" style="margin: 0;">
                      <thead>
                        <tr>
                          <th>Event</th>
                          <th>Timestamp</th>
                          <th>Details</th>
                        </tr>
                      </thead>
                      <tbody>
                  HTML

                    events.each do |event|
                      event_class =
                        case event.event_type
                        when "pending"
                          "warning"
                        when "sent"
                          "info"
                        when "delivered"
                          "success"
                        when "bounce", "complaint", "failed"
                          "danger"
                        when "open", "click"
                          "primary"
                        else
                          "default"
                        end

                      details = []
                      if event.error_message.present?
                        details << "Error: #{event.error_message}"
                      end
                      if event.bounce_type.present?
                        details << "Type: #{event.bounce_type}"
                      end

                      event_data = event.event_details
                      if event_data.present?
                        delivery_data = event_data["delivery"]
                        if delivery_data
                          if delivery_data["processingTimeMillis"]
                            details << "Processing: #{delivery_data["processingTimeMillis"]}ms"
                          end
                          if delivery_data["smtpResponse"]
                            details << "SMTP: #{delivery_data["smtpResponse"]}"
                          end
                        end

                        if event_data["feedback_type"]
                          details << "Feedback Type: #{event_data["feedback_type"]}"
                        end
                        if event_data["user_agent"]
                          details << "User Agent: #{event_data["user_agent"]}"
                        end
                        details << "IP: #{event_data["ip"]}" if event_data["ip"]
                        if event_data["url"]
                          details << "URL: #{event_data["url"]}"
                        end
                      end

                      detail_text =
                        details.any? ? details.join("<br>").html_safe : "-"

                      timeline_html += <<~HTML
                      <tr class="info">
                        <td>
                          <span class="label label-#{event_class}">
                            #{event.display_event}
                          </span>
                        </td>
                        <td>#{event.created_at}</td>
                        <td>#{detail_text}</td>
                      </tr>
                    HTML
                    end

                    timeline_html += <<~HTML
                      </tbody>
                    </table>
                  HTML

                    timeline_html.html_safe
                  else
                    no_events_style =
                      "padding: 20px; background: #f8f9fa; border-radius: 3px; color: #666;"
                    %(<div style="#{no_events_style}">No events recorded for this email</div>).html_safe
                  end
                end
              end
            end

            group :email_preview do
              label "Email Preview"
              field :email_preview do
                label ""
                formatted_value do
                  if bindings[:object].mailer_class.present? &&
                       bindings[:object].mailer_method.present?
                    begin
                      html_content =
                        EmailPreviewer.generate_preview(bindings[:object])

                      if html_content.present?
                        encoded_content = Base64.strict_encode64(html_content)
                        <<~HTML.html_safe
                        <iframe
                          src="data:text/html;base64,#{encoded_content}"
                          style="width: 100%; height: 600px; border: none; display: block;"
                          sandbox="allow-same-origin allow-scripts">
                        </iframe>
                      HTML
                      else
                        unavailable_style =
                          "padding: 20px; background: #f8f9fa; border-radius: 3px; color: #666;"
                        %(<div style="#{unavailable_style}">Email preview not available</div>).html_safe
                      end
                    rescue => e
                      error_style =
                        "padding: 20px; background: #f8f9fa; border-radius: 3px; color: #d32f2f;"
                      %(<div style="#{error_style}">Error generating preview: #{e.message}</div>).html_safe
                    end
                  else
                    fallback_style =
                      "padding: 20px; background: #f8f9fa; border-radius: 3px; color: #666;"
                    %(<div style="#{fallback_style}">Email preview not available</div>).html_safe
                  end
                end
              end
            end

            group :email_metadata do
              label "Email Metadata"

              field :metadata do
                formatted_value do
                  if bindings[:object].metadata.present?
                    metadata_style =
                      "background: #f5f5f5; padding: 10px; border-radius: 3px; max-height: 400px; overflow-y: auto;"
                    %(<pre style="#{metadata_style}">#{JSON.pretty_generate(bindings[:object].metadata)}</pre>).html_safe
                  else
                    "No metadata available"
                  end
                end
              end
            end
          end

          edit do
            field :recipient
            field :subject
            field :mailer_class
            field :mailer_method
          end
        end
      end

      private

      def badge(event_type, label)
        mapping = {
          "pending" => "warning",
          "sent" => "info",
          "delivered" => "success",
          "bounce" => "danger",
          "complaint" => "danger",
          "failed" => "danger",
          "suppressed" => "default",
          "open" => "primary",
          "click" => "primary",
        }

        css_class = mapping.fetch(event_type.to_s, "default")
        %(<span class="label label-#{css_class}">#{label}</span>).html_safe
      end
    end
  end
end
