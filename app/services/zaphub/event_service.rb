module Zaphub
  class EventService
    attr_reader :message, :event, :data

    def initialize(message:, event:, data: {})
      @message = message
      @event = event
      @data = data || {}
    end

    def perform
      return unless zaphub_channel?
      return unless channel.session_id.present?
      return if message_identifier.blank?

      payload = build_payload
      Zaphub::SessionService.new(channel).send_event(event, payload)
    rescue StandardError => e
      Rails.logger.error "[Zaphub] Event #{event} failed for message #{message.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      nil
    end

    private

    def zaphub_channel?
      message.inbox.channel_type == 'Channel::Zaphub'
    end

    def channel
      @channel ||= message.inbox.channel
    end

    def message_identifier
      message.source_id.presence ||
        message.external_source_id_zaphub.presence ||
        "chatwoot-#{message.id}"
    end

    def build_payload
      base = { messageId: message_identifier }
      return base if data.blank?

      base.merge(data)
    end
  end
end
