module Messages
  class DispatchScheduledMessageJob < ApplicationJob
    queue_as :scheduled_jobs

    discard_on ActiveJob::DeserializationError

    def perform(message_id)
      message = Message.find_by(id: message_id)
      return unless message&.scheduled_at.present?

      schedule_record = message.scheduled_message_job
      return unless schedule_record
      return unless schedule_record.scheduled?
      current_job_id = provider_job_id || job_id
      return if schedule_record.job_id.present? && schedule_record.job_id != current_job_id

      return if reschedule_if_early(message, schedule_record)

      schedule_record.update!(status: ScheduledMessageJob.statuses[:processing], dispatched_at: Time.current)

      ApplicationRecord.transaction do
        execute_delivery!(message)
      end

      delivery_service(message, schedule_record).mark_sent!
    rescue StandardError => error
      delivery_service(message, schedule_record).mark_failed!(error) if message && schedule_record
      Rails.logger.error("Scheduled message dispatch failed for message #{message_id}: #{error.message}")
      Rails.logger.error(error.backtrace.join("\n")) if error.backtrace
      raise
    end

    private

    def execute_delivery!(message)
      info = message.schedule_info.is_a?(Hash) ? message.schedule_info.deep_dup : {}
      info['dispatched_at'] = Time.current.iso8601
      message.update_columns(schedule_info: info, updated_at: Time.current)

      message.send(:deliver_outgoing!, force_send: true)
      message.update_columns(status: Message.statuses[:sent], updated_at: Time.current)
    end

    def delivery_service(message, schedule_record)
      timezone = schedule_record&.timezone
      metadata = schedule_record&.metadata || {}

      Messages::ScheduledDeliveryService.new(
        message: message,
        scheduled_at: message.scheduled_at,
        timezone: timezone,
        metadata: metadata
      )
    end

    def reschedule_if_early(message, schedule_record)
      scheduled_at = schedule_record.scheduled_at || message.scheduled_at
      return false if scheduled_at.blank? || scheduled_at <= Time.current

      delivery_service(message, schedule_record).schedule!
      true
    end
  end
end
