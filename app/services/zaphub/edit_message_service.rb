module Zaphub
  class EditMessageService
    pattr_initialize [:message!, :new_content!]

    def perform
      return unless zaphub_channel?
      return unless message.outgoing?
      return if message.source_id.blank?
      return if channel.session_id.blank?

      edit_zaphub_message
    rescue StandardError => e
      Rails.logger.error "ZapHub edit message error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      # Don't raise - allow local edit to continue
      nil
    end

    private

    def zaphub_channel?
      message.inbox.channel_type == 'Channel::Zaphub'
    end

    def channel
      @channel ||= message.inbox.channel
    end

    def edit_zaphub_message
      message_id = message.source_id || message.external_source_id_zaphub
      return if message_id.blank?

      payload = {
        content: {
          text: new_content
        }
      }

      response = Zaphub::SessionService.new(channel).edit_message(message_id, payload)
      
      Rails.logger.info "[Zaphub] Message #{message.id} edited successfully via Zaphub"
      
      response
    end
  end
end

