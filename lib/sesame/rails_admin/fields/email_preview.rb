# frozen_string_literal: true

require "base64"

module Sesame
  module RailsAdmin
    module Fields
      module EmailPreview
        module_function

        def apply(field)
          field.label ""

          field.register_instance_option :formatted_value do
            if bindings[:object].mailer_class.present? &&
                 bindings[:object].mailer_method.present?
              begin
                html_content = Sesame::EmailPreviewer.generate_preview(bindings[:object])

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
                  unavailable_message
                end
              rescue => e
                Rails.logger.error("Sesame preview render error: #{e.message}") if defined?(Rails)
                error_message(e.message)
              end
            else
              unavailable_message
            end
          end
        end

        def unavailable_message
          style =
            "padding: 20px; background: #f8f9fa; border-radius: 3px; color: #666;"
          %(<div style="#{style}">Email preview not available</div>).html_safe
        end
        private_class_method :unavailable_message

        def error_message(message)
          style =
            "padding: 20px; background: #f8f9fa; border-radius: 3px; color: #d32f2f;"
          %(<div style="#{style}">Error generating preview: #{message}</div>).html_safe
        end
        private_class_method :error_message
      end
    end
  end
end
