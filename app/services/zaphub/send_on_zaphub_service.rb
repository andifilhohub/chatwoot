module Zaphub
  class SendOnZaphubService < Base::SendOnChannelService
    private

    def channel_class
      Channel::Zaphub
    end

    def perform_reply
      send_zaphub_message
    end

    def send_zaphub_message
      message_payload = build_message_payload
      
      response = Zaphub::SessionService.new(channel).send_message(message_payload)
      
      # Update message with external ID
      if response['messageId']
        message.update!(
          source_id: response['messageId'],
          external_source_id_zaphub: response['messageId']
        )
        Rails.logger.info "[Zaphub] Updated message #{message.id} with source_id: #{response['messageId']}"
      end
      
      response
    rescue StandardError => e
      Rails.logger.error "ZapHub send message error: #{e.message}"
      raise
    end

    def build_message_payload
      payload = {
        messageId: "msg-#{message.id}-#{Time.current.to_i}",
        to: contact_phone_number,
        type: message_type
      }

      case message_type
      when 'text'
        payload[:text] = message.content
      when 'image', 'video', 'audio', 'document'
        payload[message_type.to_sym] = build_media_payload
      end

      payload
    end

    def message_type
      return 'text' unless message.attachments.any?

      attachment = message.attachments.first
      
      case attachment.file_type
      when 'image'
        'image'
      when 'video'
        'video'
      when 'audio'
        'audio'
      when 'file'
        'document'
      else
        'text'
      end
    end

    def build_media_payload
      attachment = message.attachments.first
      
      media_data = {
        url: attachment.download_url
      }

      case attachment.file_type
      when 'image'
        media_data[:caption] = message.content if message.content.present?
      when 'video'
        media_data[:caption] = message.content if message.content.present?
      when 'document'
        media_data[:fileName] = attachment.file.filename.to_s
        media_data[:mimetype] = attachment.file.content_type
      when 'audio'
        media_data[:ptt] = true # Push-to-talk voice message
      end

      media_data
    end

    def contact_phone_number
      chat_id = message.conversation.additional_attributes&.dig('chat_id')
      normalized_chat_id = normalize_chat_identifier(chat_id)
      return normalized_chat_id if normalized_chat_id.present?

      phone = message.conversation.contact.phone_number.to_s
      return phone if phone.include?('@')

      digits = phone.gsub(/\D/, '')
      return nil if digits.blank?

      "#{digits}@s.whatsapp.net"
    end

    def normalize_chat_identifier(identifier)
      return nil if identifier.blank?

      jid = identifier.to_s
      return jid if jid.match?(/@(s\.whatsapp\.net|g\.us)\z/)

      return nil unless jid.include?('@lid')

      base = jid.split('@').first
      base = base.split(':').first
      digits = base.gsub(/\D/, '')
      return nil if digits.blank?

      "#{digits}@s.whatsapp.net"
    end

    def inbox
      @inbox ||= message.inbox
    end

    def channel
      @channel ||= inbox.channel
    end

    def outgoing_message?
      message.outgoing? || message.template?
    end
  end
end
