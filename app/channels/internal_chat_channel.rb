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
    
    # Para teste, aceita qualquer conexão
    stream_from stream_name
    
    Rails.logger.info "🔌 InternalChatChannel: Subscribed to #{stream_name}"
  end

  def unsubscribed
    Rails.logger.info "👋 InternalChatChannel: Unsubscribed"
  end

  def receive(data)
    return unless current_user && current_account
    
    Rails.logger.info "💬 ActionCable: Message received: #{data.inspect}"

    content = data['content']
    room_type = data['room_type'] || 'general'
    room_id = data['room_id'] || 'general'

    # Encontrar ou criar sala
    room = find_or_create_room(room_type, room_id)
    return unless room

    # Criar mensagem
    Rails.logger.info "🔧 ActionCable: Creating message with room_id: #{room.id}"
    message = GcInternalChatMessage.create!(
      room_id: room.id,
      account_id: current_account.id,
      sender_id: current_user.id,
      content: content
    )

    Rails.logger.info "✅ ActionCable: Message created ##{message.id}"

    # Serializar mensagem
    serialized_message = {
      id: message.id,
      content: message.content,
      sender: {
        id: message.sender.id,
        name: message.sender.name,
        avatar_url: message.sender.avatar_url
      },
      sender_id: message.sender.id,
      created_at: message.created_at.iso8601,
      message_type: 'text',
      chat_type: room_type,
      chat_id: room_id,
      room_id: room.id
    }

    # Broadcast
    ActionCable.server.broadcast(
      stream_name,
      {
        type: 'new_message',
        message: serialized_message,
        timestamp: message.created_at.iso8601
      }
    )

    Rails.logger.info "📡 ActionCable: Message broadcasted"
  rescue => e
    Rails.logger.error "❌ ActionCable Error: #{e.message}"
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

    @current_account ||= begin
      account = if params[:account_id].present?
                  current_user.accounts.find_by(id: params[:account_id])
                else
                  current_user.accounts.first
                end

      if account.blank? && params[:account_id].present?
        account = Account.find_by(id: params[:account_id])
        Rails.logger.debug "ℹ️ InternalChatChannel: fallback account lookup for user #{current_user.id}" if account
      end

      account
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
  def stream_name
    "internal_chat_#{current_account.id}"
  end

  def find_or_create_room(room_type, room_id)
    Rails.logger.info "🔍 ActionCable: Finding room: type=#{room_type}, id=#{room_id}"
    
    case room_type.to_s
    when 'general'
      room = GcInternalChatRoom.find_or_create_general(current_account)
      Rails.logger.info "🔍 ActionCable: General room: #{room&.id}"
      room
    when 'direct'
      # Para direct, room_id pode ser o ID da sala ou do usuário alvo
      if room_id.to_s.match?(/^\d+$/)
        # Primeiro tenta buscar sala por ID
        room = current_account.gc_internal_chat_rooms.find_by(id: room_id, room_type: :direct)
        if room
          Rails.logger.info "🔍 ActionCable: Found direct room by ID: #{room.id}"
          return room
        end
        
        # Se não encontrou, trata como user_id
        target_user = find_user_by_id(room_id)
        if target_user
          Rails.logger.info "🔍 ActionCable: Creating direct room for user: #{target_user.id}"
          room = GcInternalChatRoom.find_or_create_direct_room(
            current_account,
            current_user,
            target_user
          )
          Rails.logger.info "🔍 ActionCable: Direct room created/found: #{room&.id}"
          return room
        end
      end
      
      Rails.logger.error "❌ ActionCable: Could not find or create direct room for #{room_id}"
      nil
    else
      Rails.logger.error "❌ ActionCable: Unknown room type: #{room_type}"
      nil
    end
  end

  def resolve_room(chat_type, payload)
    case chat_type
    when 'general'
      room = GcInternalChatRoom.find_or_create_general(current_account)
      ensure_room_membership(room, current_user)
      { room: room, chat_id: 'general' }
    when 'team'
      team_id = payload[:team_id] || payload[:chat_id]
      team = current_account.teams.find_by(id: team_id)
      return nil unless team

      room = GcInternalChatRoom.find_or_create_team_room(team)
      ensure_room_membership(room, current_user)
      { room: room, chat_id: team.id }
    when 'direct'
      recipient_id = payload[:recipient_id] || payload[:chat_id]
      recipient = find_user_by_id(recipient_id)
      return nil unless recipient

      room = GcInternalChatRoom.find_or_create_direct_room(
        current_account,
        current_user,
        recipient
      )

      ensure_room_membership(room, current_user)
      ensure_room_membership(room, recipient)

      { room: room, chat_id: recipient.id }
    else
      nil
    end
  end

  def create_message(room, content, attachments = [])
    Rails.logger.info "🔧 Creating message in room #{room.id} with content: '#{content}'"
    Rails.logger.info "🔧 Room: #{room.inspect}"
    Rails.logger.info "🔧 Current account: #{current_account&.id}"
    Rails.logger.info "🔧 Current user: #{current_user&.id}"
    
    if content.to_s.strip.blank? && Array(attachments).blank?
      Rails.logger.warn "⚠️ No content or attachments provided, but allowing for debug"
      content = "[Mensagem vazia via ActionCable]"
    end

    begin
      message = GcInternalChatMessage.create!(
        room: room,
        account: current_account,
        sender: current_user,
        content: content,
        metadata: {}
      )
      Rails.logger.info "✅ ActionCable: created message ##{message.id} in room #{room.id}"
      message
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "❌ ActionCable: Message validation failed: #{e.record.errors.full_messages.join(', ')}"
      Rails.logger.error "❌ ActionCable: Record: #{e.record.inspect}"
      nil
    rescue => e
      Rails.logger.error "❌ ActionCable: Error creating message: #{e.message}"
      Rails.logger.error "❌ ActionCable: Backtrace: #{e.backtrace.first(5).join('\n')}"
      nil
    end
  end

  def serialize_message(message, chat_type:, chat_id:, room:)
    has_attachments = message.respond_to?(:attachments) && message.attachments.any?
    message_type = has_attachments && message.content.to_s.strip.blank? ? 'attachment' : 'text'

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
    return [] unless message.respond_to?(:attachments)

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

  def ensure_room_membership(room, user)
    return unless room && user

    room.add_member(user)
  end
end
