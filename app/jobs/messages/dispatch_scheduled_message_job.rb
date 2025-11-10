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
      return if schedule_record.job_id.present? && schedule_record.job_id != job_id

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
      message.update!(schedule_info: info)

      message.notify_via_mail
      message.execute_message_template_hooks
      message.conversation.update_columns(last_activity_at: Time.current)
      message.send_reply
      Messages::StatusUpdateService.new(message, 'sent').perform
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
  end
end
