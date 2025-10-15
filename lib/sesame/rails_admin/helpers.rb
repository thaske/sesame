# frozen_string_literal: true

module Sesame
  module RailsAdmin
    module Helpers
      module_function

      require "active_support/core_ext/string/output_safety"

      BADGE_CLASS_MAPPING = {
        "pending" => "warning",
        "sent" => "info",
        "delivered" => "success",
        "bounce" => "danger",
        "complaint" => "danger",
        "failed" => "danger",
        "suppressed" => "default",
        "open" => "primary",
        "click" => "primary",
      }.freeze

      def badge(event_type, label)
        css_class = BADGE_CLASS_MAPPING.fetch(event_type.to_s, "default")
        %(<span class="label label-#{css_class}">#{label}</span>).html_safe
      end
    end
  end
end
