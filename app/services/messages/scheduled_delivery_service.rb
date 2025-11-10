module Messages
  class ScheduledDeliveryService
    attr_reader :message, :scheduled_at, :timezone, :metadata

    def initialize(message:, scheduled_at:, timezone: nil, metadata: {})
      @message = message
      @scheduled_at = scheduled_at
      @timezone = timezone
      @metadata = (metadata || {}).with_indifferent_access
    end

    def schedule!
      ActiveRecord::Base.transaction do
        schedule_record = message.scheduled_message_job || message.build_scheduled_message_job
        schedule_record.assign_attributes(
          scheduled_at: scheduled_at,
          timezone: timezone,
          status: ScheduledMessageJob.statuses[:scheduled],
          dispatched_at: nil,
          error_message: nil,
          metadata: merged_metadata(schedule_record.metadata)
        )
        schedule_record.save!
        enqueue_job!(schedule_record)
      end
    end

    def mark_sent!
      update_status!(ScheduledMessageJob.statuses[:sent], dispatched_at: Time.current)
    end

    def mark_failed!(error)
      update_status!(ScheduledMessageJob.statuses[:failed], error_message: error.to_s, dispatched_at: Time.current)
    end

    def cancel!(reason: nil)
      update_status!(ScheduledMessageJob.statuses[:cancelled], error_message: reason)
    end

    private

    def enqueue_job!(schedule_record)
      job = Messages::DispatchScheduledMessageJob.set(wait_until: scheduled_at).perform_later(message.id)
      provider_id = job.respond_to?(:provider_job_id) ? job.provider_job_id : nil
      schedule_record.update!(job_id: provider_id || job.job_id)
    end

    def merged_metadata(existing_metadata)
      payload = (existing_metadata || {}).with_indifferent_access
      payload.merge(metadata).merge(
        scheduled_at: scheduled_at.iso8601,
        scheduled_timezone: timezone
      ).compact
    end

    def update_status!(status, extra_attributes = {})
      record = message.scheduled_message_job
      return unless record

      record.update!(extra_attributes.merge(status: status))
    end
  end
end
