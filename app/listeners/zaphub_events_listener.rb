class ZaphubEventsListener < BaseListener
  def message_created(event)
    message = extract_message_and_account(event)[0]
    inbox = message.inbox
    
    return unless inbox&.channel_type == 'Channel::Zaphub'
    return unless message.outgoing? || message.template?
    return if message.private?
    return if message.content_type == 'input_csat'
    return if message.source_id.present? # Already sent

    Zaphub::SendOnZaphubService.new(message: message).perform
  end
end
