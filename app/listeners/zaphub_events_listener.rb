class ZaphubEventsListener < BaseListener
  def message_created(event)
    message = extract_message_and_account(event)[0]
    inbox = message.inbox
    
    Rails.logger.info("[Zaphub] Listener triggered for message #{message.id} inbox=#{inbox&.id} channel_type=#{inbox&.channel_type} source_id=#{message.source_id.inspect} type=#{message.message_type}")

    unless inbox&.channel_type == 'Channel::Zaphub'
      Rails.logger.info("[Zaphub] Skip send: inbox not ZapHub (inbox_id=#{inbox&.id})")
      return
    end
    unless message.outgoing? || message.template?
      Rails.logger.info("[Zaphub] Skip send: not outgoing/template (message_id=#{message.id} type=#{message.message_type})")
      return
    end
    if message.private?
      Rails.logger.info("[Zaphub] Skip send: private message #{message.id}")
      return
    end
    if message.content_type == 'input_csat'
      Rails.logger.info("[Zaphub] Skip send: CSAT message #{message.id}")
      return
    end
    if message.source_id.present?
      Rails.logger.info("[Zaphub] Skip send: already has source_id #{message.id} source_id=#{message.source_id}")
      return
    end

    Zaphub::SendOnZaphubService.new(message: message).perform
  end
end
