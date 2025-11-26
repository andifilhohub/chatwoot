class Conversations::UpdateMessageStatusJob < ApplicationJob
  queue_as :deferred

  # This job only support marking messages as read or delivered, update this array if we want to support more statuses
  VALID_STATUSES = %w[read delivered].freeze
  STATUS_EVENT_MAP = {
    'read' => 'message.read',
    'delivered' => 'message.delivered'
  }.freeze

  def perform(conversation_id, timestamp, status = :read)
    return unless VALID_STATUSES.include?(status.to_s)

    conversation = Conversation.find_by(id: conversation_id)

    return unless conversation

    # Mark every message created before the user's viewing time read or delivered
    conversation.messages.where(status: %w[sent delivered])
                .where.not(message_type: 'incoming')
                .where('messages.created_at <= ?', timestamp).find_each do |message|
      service = Messages::StatusUpdateService.new(message, status)
      next unless service.perform

      send_status_event(message, status)
    end
  end

  private

  def send_status_event(message, status)
    return unless message.inbox.channel_type == 'Channel::Zaphub'

    event = STATUS_EVENT_MAP[status.to_s]
    return unless event

    Zaphub::EventService.new(message: message, event: event, data: { status: status.to_s }).perform
  end
end
