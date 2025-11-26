module Zaphub
  class DeleteMessageService
    pattr_initialize [:message!]

    def perform
      return unless zaphub_channel?
      return unless message.outgoing?
      return if message.source_id.blank?
      return if channel.session_id.blank?

      delete_zaphub_message
    rescue StandardError => e
      Rails.logger.error "ZapHub delete message error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      # Don't raise - allow local deletion to continue
      nil
    end

    private

    def zaphub_channel?
      message.inbox.channel_type == 'Channel::Zaphub'
    end

    def channel
      @channel ||= message.inbox.channel
    end

    def delete_zaphub_message
      message_id = message.source_id || message.external_source_id_zaphub
      return if message_id.blank?

      response = Zaphub::SessionService.new(channel).delete_message(message_id)
      
      Rails.logger.info "[Zaphub] Message #{message.id} deleted successfully via Zaphub"
      
      response
    end
  end
end

