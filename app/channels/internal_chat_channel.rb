class InternalChatChannel < ApplicationCable::Channel
  def subscribed
    Rails.logger.info "✅ InternalChatChannel: Subscription attempt"
    Rails.logger.info "📋 Subscription params: #{params.inspect}"
    Rails.logger.info "👤 Current user: #{current_user&.id} - #{current_user&.name}"
    Rails.logger.info "🏢 Current account: #{current_account&.id} - #{current_account&.name}"
    
    # Verificar se usuário e conta existem
    unless current_user && current_account
      Rails.logger.error "❌ Subscription rejected: missing user or account"
      reject
      return
    end
    
    # Força o carregamento das models GeniusCloud
    ensure_genius_cloud_models
    
    # Para teste, aceita qualquer conexão
    stream_from stream_name
    
    Rails.logger.info "🔌 InternalChatChannel: Subscribed to #{stream_name}"
  end

  def unsubscribed
    Rails.logger.info "👋 InternalChatChannel: Unsubscribed"
  end

  def receive(data)
    return unless current_user && current_account
    
    Rails.logger.info "💬 InternalChatChannel: Message received from user #{current_user.id}: #{data.inspect}"

    payload = data.with_indifferent_access
    chat_type = payload[:chat_type].presence || 'general'

    room_resolution = resolve_room(chat_type, payload)
    unless room_resolution
      Rails.logger.warn "❌ InternalChatChannel: Unable to resolve room for payload #{payload.inspect}"
      return
    end

    room = room_resolution[:room]
    chat_id = room_resolution[:chat_id]

    message = create_message(room, payload[:content], payload[:attachments])
    return unless message

    serialized = serialize_message(message, chat_type: room.room_type, chat_id: chat_id, room: room)

    ActionCable.server.broadcast(
      stream_name,
      {
        type: 'new_message',
        chat_type: room.room_type,
        chat_id: chat_id,
        message: serialized,
        timestamp: message.created_at.iso8601
      }
    )

    Rails.logger.info "📡 InternalChatChannel: Message broadcasted to #{stream_name}"
  end

  private

  def current_user
    @current_user ||= begin
      if params[:user_id].present? && params[:pubsub_token].present?
        find_user_by_pubsub_token(params[:user_id], params[:pubsub_token])
      elsif params[:pubsub_token].present?
        User.find_by(pubsub_token: params[:pubsub_token])
      end
    end
  end

  def current_account
    return if current_user.blank?

    @current_account ||= if params[:account_id].present?
                           current_user.accounts.find_by(id: params[:account_id])
                         else
                           current_user.accounts.first
                         end
  end

  def find_user_by_pubsub_token(user_id, pubsub_token)
    # Tentar buscar como User primeiro
    user = User.find_by(pubsub_token: pubsub_token, id: user_id)
    
    # Se não encontrar, tentar como SuperAdmin
    unless user
      user = SuperAdmin.find_by(pubsub_token: pubsub_token, id: user_id)
    end
    
    Rails.logger.info "🔍 Found user: #{user&.class&.name} ID=#{user&.id} Name=#{user&.name}" if user
    user
  rescue ActiveRecord::SubclassNotFound => e
    Rails.logger.warn "⚠️ STI Error in find_user_by_pubsub_token: #{e.message}"
    nil
  end
  def ensure_genius_cloud_models
    ensure_dependency('models', 'genius_cloud/internal_chat/room') { ::GeniusCloud::InternalChat::Room }
    ensure_dependency('models', 'genius_cloud/internal_chat/message') { ::GeniusCloud::InternalChat::Message }
    ensure_dependency('models', 'genius_cloud/internal_chat/membership') { ::GeniusCloud::InternalChat::Membership }
    ensure_dependency('services', 'genius_cloud/internal_chat/message_builder') { ::GeniusCloud::InternalChat::MessageBuilder }
    ensure_dependency('services', 'genius_cloud/internal_chat/direct_room_builder') { ::GeniusCloud::InternalChat::DirectRoomBuilder }
  rescue => e
    Rails.logger.error "❌ Error loading GeniusCloud models: #{e.message}"
  end

  def stream_name
    "internal_chat_#{current_account.id}"
  end

  def resolve_room(chat_type, payload)
    case chat_type
    when 'general'
      room = ::GeniusCloud::InternalChat::Room.ensure_general!(current_account)
      { room: room, chat_id: 'general' }
    when 'team'
      team_id = payload[:team_id]
      team = current_account.teams.find_by(id: team_id)
      return nil unless team

      room = ::GeniusCloud::InternalChat::Room.ensure_team!(team)
      { room: room, chat_id: team.id }
    when 'direct'
      recipient = find_user_by_id(payload[:recipient_id])
      return nil unless recipient

      room = ::GeniusCloud::InternalChat::DirectRoomBuilder.new(
        account: current_account,
        initiating_user: current_user,
        target_user: recipient
      ).find_or_create

      { room: room, chat_id: recipient.id }
    else
      nil
    end
  end

  def create_message(room, content, attachments = [])
    if content.to_s.strip.blank? && Array(attachments).blank?
      Rails.logger.error "❌ No content or attachments provided for message creation"
      return nil
    end

    builder = ::GeniusCloud::InternalChat::MessageBuilder.new(
      room: room,
      sender: current_user,
      params: {
        content: content,
        attachments: Array(attachments).select(&:present?)
      }
    )

    builder.create!
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "❌ Message validation failed: #{e.record.errors.full_messages.join(', ')}"
    nil
  rescue => e
    Rails.logger.error "❌ Error creating message: #{e.message}"
    nil
  end

  def serialize_message(message, chat_type:, chat_id:, room:)
    message_type = message.attachments.any? && message.content.to_s.strip.blank? ? 'attachment' : 'text'

    {
      id: message.id,
      content: message.content,
      sender: sender_payload(message.sender),
      sender_id: message.sender_id,
      created_at: message.created_at.iso8601,
      message_type: message_type,
      chat_type: chat_type,
      chat_id: chat_id,
      room_id: room.id,
      attachments: attachments_payload_for(message)
    }
  end

  def sender_payload(sender)
    return { id: nil, name: 'Unknown', avatar_url: nil } unless sender

    {
      id: sender.id,
      name: sender.name,
      avatar_url: sender.avatar_url
    }
  end

  def attachments_payload_for(message)
    message.attachments.includes(:file_attachment).map do |attachment|
      next unless attachment.file.attached?
      
      blob = attachment.file.blob
      {
        id: attachment.id,
        message_id: attachment.message_id,
        file_type: attachment.file_type,
        account_id: attachment.account_id,
        extension: attachment.extension,
        data_url: attachment.file_url,
        thumb_url: attachment.thumb_url,
        file_size: blob.byte_size,
        width: blob.metadata[:width],
        height: blob.metadata[:height]
      }
    end.compact
  end

  def find_user_by_id(user_id)
    return if user_id.blank?

    account_user = current_account.account_users.includes(:user).find_by(user_id: user_id)
    return account_user.user if account_user

    super_admin = SuperAdmin.find_by(id: user_id)
    return super_admin if super_admin&.accounts&.include?(current_account)

    nil
  rescue ActiveRecord::SubclassNotFound => e
    Rails.logger.warn "⚠️ STI Error finding user #{user_id}: #{e.message}"
    nil
  end

  def ensure_dependency(type, relative_path)
    yield
  rescue NameError
    # GeniusCloud-modify directory was removed
    raise NameError, "Required dependency not found: #{type}/#{relative_path}"
  end
end
