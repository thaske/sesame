# frozen_string_literal: true

module Sesame
  class SuppressionFilter
    class << self
      def can_send_to?(email)
        return false if email.blank?

        !::EmailSuppression.suppressed?(email)
      end

      def filter_recipients(recipients)
        return [] if recipients.blank?

        recipients = Array(recipients).map { |addr| addr.to_s.downcase }.uniq
        suppressed = ::EmailSuppression.where(email: recipients).pluck(:email)

        recipients - suppressed
      end

      def add_suppression(email, type:, reason:, metadata: {})
        ::EmailSuppression.create!(
          email: email.downcase,
          suppression_type: type,
          reason: reason,
          message_id: metadata[:message_id],
          feedback_id: metadata[:feedback_id],
          source_ip: metadata[:source_ip],
          source_arn: metadata[:source_arn],
          raw_message: metadata[:raw_message],
          suppressed_at: Time.current,
        )
      end

      def remove_suppression(email)
        ::EmailSuppression.where(email: email.downcase).destroy_all
      end

      def suppression_stats
        {
          total: ::EmailSuppression.count,
          bounces: ::EmailSuppression.bounces.count,
          complaints: ::EmailSuppression.complaints.count,
          permanent_bounces: ::EmailSuppression.permanent_bounces.count,
          transient_bounces:
            ::EmailSuppression.bounces.where(reason: "transient").count,
          recent_24h:
            ::EmailSuppression.where(created_at: 24.hours.ago..).count,
          recent_7d: ::EmailSuppression.where(created_at: 7.days.ago..).count,
          recent_30d: ::EmailSuppression.where(created_at: 30.days.ago..).count,
          by_reason: suppression_stats_by_reason,
          growth_rate: calculate_growth_rate,
        }
      end

      private

      def suppression_stats_by_reason
        ::EmailSuppression
          .group(:suppression_type, :reason)
          .count
          .transform_keys { |(type, reason)| "#{type}_#{reason}" }
      end

      def calculate_growth_rate
        current_week = ::EmailSuppression.where(created_at: 1.week.ago..).count
        previous_week =
          ::EmailSuppression.where(created_at: 2.weeks.ago..1.week.ago).count

        return 0 if previous_week.zero?

        ((current_week - previous_week) / previous_week.to_f * 100).round(2)
      end
    end
  end
end
