# frozen_string_literal: true

class Api::V1::Accounts::InternalChatController < Api::V1::Accounts::BaseController
  before_action :ensure_internal_chat_models

  def rooms
    general_room = ensure_general_room

    teams_payload = Current.account.teams.includes(:members).map do |team|
      room = ensure_team_room(team)
      {
        id: team.id,
        name: team.name,
        room_id: room.id,
        type: 'team',
        room_type: 'team',
        identifier: team.id,
        member_count: team.members.count,
        description: team.description || 'Equipe'
      }
    end

    # Buscar usuários da conta (agents e administrators)
    account_users = Current.account.account_users.includes(:user)
                           .where.not(users: { id: Current.user.id })
                           .map do |account_user|
      next unless account_user.user

      user = account_user.user
      status = account_user.availability_status || 'offline'
      direct_key = [Current.user.id, user.id].sort.join('-')
      room = Current.account.gc_internal_chat_rooms.find_by(room_type: :direct, direct_key: direct_key)

      {
        id: user.id,
        name: user.name,
        email: user.email,
        avatar_url: user.avatar_url,
        availability_status: status.to_s.downcase,
        last_seen_at: user.last_sign_in_at,
        room_id: room&.id,
        room_type: 'direct',
        identifier: user.id
      }
    end.compact

    # Se o usuário atual é SuperAdmin, incluir outros SuperAdmins
    super_admin_users = []
    if Current.user.is_a?(SuperAdmin)
      super_admin_users = SuperAdmin.where.not(id: Current.user.id).map do |super_admin|
        direct_key = [Current.user.id, super_admin.id].sort.join('-')
        room = Current.account.gc_internal_chat_rooms.find_by(room_type: :direct, direct_key: direct_key)

        {
          id: super_admin.id,
          name: super_admin.name,
          email: super_admin.email,
          avatar_url: super_admin.avatar_url,
          availability_status: 'online', # SuperAdmins sempre online
          last_seen_at: super_admin.last_sign_in_at,
          room_id: room&.id,
          room_type: 'direct',
          identifier: super_admin.id
        }
      end
    end

    direct_payload = account_users + super_admin_users

    @rooms = {
      general: {
        id: 'general',
        identifier: 'general',
        room_id: general_room.id,
        name: general_room.name,
        type: 'general',
        room_type: 'general',
        description: general_room.metadata&.dig('description') || 'Conversas gerais da equipe'
      },
      teams: teams_payload,
      direct_messages: direct_payload
    }

    # Variáveis para o template
    @general_room = @rooms[:general]
    @teams_payload = teams_payload
    @direct_payload = direct_payload

    Rails.logger.info "🏠 Rooms loaded for account #{Current.account.id}: #{@rooms.keys}"
  end

  def create_room
    # Aceitar parâmetros tanto no formato "room" quanto diretamente
    if params[:room].present?
      room_params = params.require(:room)
      room_type = room_params[:room_type] || 'direct'
      target_user_id = room_params[:target_user_id]
    else
      room_type = params[:room_type] || 'direct'
      target_user_id = params[:target_user_id]
    end

    Rails.logger.info "🆕 Creating room: #{room_type} for user #{target_user_id}"

    if room_type == 'direct'
      # Generate direct key for the room
      direct_key = "direct-#{[Current.user.id, target_user_id].sort.join('-')}"
      
      # Find existing room by direct_key or create new one
      @room = Current.account.gc_internal_chat_rooms.find_by(direct_key: direct_key)
      
      if @room
        Rails.logger.info "✅ Found existing direct room: #{@room.id}"
      else
        # Create new direct room
        @room = Current.account.gc_internal_chat_rooms.create!(
          room_type: 'direct',
          name: "Direct Chat",
          slug: direct_key,
          direct_key: direct_key
        )
        
        # Add memberships (participants)
        @room.gc_internal_chat_memberships.create!(user_id: Current.user.id)
        @room.gc_internal_chat_memberships.create!(user_id: target_user_id)
        
        Rails.logger.info "✅ Created new direct room: #{@room.id}"
      end

      [Current.user, find_user_by_id(target_user_id)].compact.each do |member|
        @room.add_member(member)
      end

      render json: {
        data: {
          id: @room.id,
          room_id: @room.id,
          type: 'direct',
          room_type: 'direct',
          target_user_id: target_user_id,
          name: @room.name,
          participants: @room.users.map do |user|
            {
              id: user.id,
              name: user.name,
              email: user.email
            }
          end
        }
      }
    else
      render json: { errors: ['Room type not supported'] }, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "❌ Error creating room: #{e.message}"
    render json: { errors: [e.message] }, status: :unprocessable_entity
  end

  def messages
    room_type = params[:room_type] || 'general'
    room_id = params[:room_id] || 'general'
    limit = params[:per_page]&.to_i || 50

    Rails.logger.info "📨 Loading messages for #{room_type}/#{room_id}"

    room = find_or_create_room(room_type, room_id)
    unless room
      return render json: { data: [], meta: { error: 'Room not found' } }
    end

    # Carregar mensagens
    messages = room.gc_internal_chat_messages
                   .active
                   .order(created_at: :desc)
                   .limit(limit)

    # Serializar mensagens
    serialized_messages = messages.map do |message|
      {
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
    end

    render json: {
      data: serialized_messages.reverse, # Ordem cronológica
      meta: {
        room_id: room.id,
        total_count: room.gc_internal_chat_messages.active.count
      }
    }
  end

  def messages_general
    params[:room_type] = 'general'
    params[:room_id] = 'general'
    messages
  end

  def send_message
    # Extrair parâmetros de forma simples
    content = params.dig(:message, :content) || params[:content]
    room_type = params.dig(:message, :room_type) || params[:room_type] || 'general'
    room_id = params.dig(:message, :room_id) || params[:room_id] || 'general'

    Rails.logger.info "📤 Sending message: '#{content}' to #{room_type}/#{room_id}"

    # Validar conteúdo
    if content.blank?
      return render json: { errors: ['Message content cannot be blank'] }, status: :unprocessable_entity
    end

    # Encontrar ou criar sala
    room = find_or_create_room(room_type, room_id)
    unless room
      return render json: { errors: ['Room not found'] }, status: :not_found
    end

    # Criar mensagem
    Rails.logger.info "🔧 Creating message with room_id: #{room.id}"
    message = GcInternalChatMessage.create!(
      room_id: room.id,
      account_id: Current.account.id,
      sender_id: Current.user.id,
      content: content
    )

    Rails.logger.info "✅ Message created: ##{message.id}"

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

    # Broadcast via ActionCable
    ActionCable.server.broadcast(
      "internal_chat_#{Current.account.id}",
      {
        type: 'new_message',
        message: serialized_message,
        timestamp: message.created_at.iso8601
      }
    )

    Rails.logger.info "📡 Message broadcasted"

    render json: { data: serialized_message }, status: :created
  rescue => e
    Rails.logger.error "❌ Error: #{e.message}"
    render json: { errors: [e.message] }, status: :unprocessable_entity
  end

  private

  def find_or_create_room(room_type, room_id)
    Rails.logger.info "🔍 Finding room: type=#{room_type}, id=#{room_id}"
    
    case room_type.to_s
    when 'general'
      room = GcInternalChatRoom.find_or_create_general(Current.account)
      Rails.logger.info "🔍 General room: #{room&.id}"
      room
    when 'direct'
      # Para direct, room_id pode ser o ID da sala ou do usuário alvo
      if room_id.to_s.match?(/^\d+$/)
        # Primeiro tenta buscar sala por ID
        room = Current.account.gc_internal_chat_rooms.find_by(id: room_id, room_type: :direct)
        if room
          Rails.logger.info "🔍 Found direct room by ID: #{room.id}"
          return room
        end
        
        # Se não encontrou, trata como user_id
        target_user = find_user_by_id(room_id)
        if target_user
          Rails.logger.info "🔍 Creating direct room for user: #{target_user.id}"
          room = GcInternalChatRoom.find_or_create_direct_room(
            Current.account,
            Current.user,
            target_user
          )
          Rails.logger.info "🔍 Direct room created/found: #{room&.id}"
          return room
        end
      end
      
      Rails.logger.error "❌ Could not find or create direct room for #{room_id}"
      nil
    else
      Rails.logger.error "❌ Unknown room type: #{room_type}"
      nil
    end
  end

  def get_recipient_id(room)
    return nil unless room.direct?

    room.direct_key.to_s.gsub('direct-', '').split('-').map(&:to_i).find { |id| id != Current.user.id }
  end

  # Método auxiliar para encontrar usuário por ID, funcionando tanto para User quanto SuperAdmin
  def find_user_by_id(user_id)
    Rails.logger.info "🔍 Searching for user_id: #{user_id}"

    account_user = Current.account.account_users.includes(:user).find_by(user_id: user_id)
    return account_user.user if account_user

    super_admin = SuperAdmin.find_by(id: user_id)

    return super_admin if super_admin&.accounts&.include?(Current.account)

    Rails.logger.warn "❌ User not found or without access: #{user_id}"
    nil
  rescue ActiveRecord::SubclassNotFound => e
    Rails.logger.warn "⚠️ STI Error finding user #{user_id}: #{e.message}"
    nil
  end

  def ensure_internal_chat_models
    # Models are now loaded automatically with Gc prefix
    true
  end

  def ensure_general_room
    GcInternalChatRoom.find_or_create_general(Current.account)
  end

  def ensure_team_room(team)
    GcInternalChatRoom.find_or_create_team_room(team)
  end

  def resolve_room(room_type, identifier, ensure_room: false)
    Rails.logger.info "🔍 Resolving room: type=#{room_type}, identifier=#{identifier}, ensure_room=#{ensure_room}"
    
    case room_type.to_s
    when 'general'
      Rails.logger.info "🔍 Resolving general room"
      room = ensure_general_room
      Rails.logger.info "🔍 General room: #{room&.id} - #{room&.name}"
      { room: room, chat_id: 'general' }
    when 'team'
      Rails.logger.info "🔍 Resolving team room for team #{identifier}"
      team = Current.account.teams.find_by(id: identifier)
      unless team
        Rails.logger.error "❌ Team not found: #{identifier}"
        return nil
      end

      room = ensure_team_room(team)
      Rails.logger.info "🔍 Team room: #{room&.id} - #{room&.name}"
      { room: room, chat_id: team.id }
    when 'direct'
      Rails.logger.info "🔍 Resolving direct room for identifier #{identifier}"
      
      # Se identifier é um ID numérico, buscar diretamente a sala
      if identifier.to_s.match?(/^\d+$/)
        Rails.logger.info "🔍 Identifier is numeric, searching for room by ID"
        room = Current.account.gc_internal_chat_rooms.find_by(id: identifier, room_type: :direct)
        if room
          target_user_id = get_recipient_id(room)
          Rails.logger.info "🔍 Found room by ID: #{room.id}, target_user_id: #{target_user_id}"
          return { room: room, chat_id: target_user_id || identifier }
        else
          Rails.logger.warn "⚠️ Room not found by ID: #{identifier}"
        end
      end
      
      # Fallback: tratar como target_user_id
      Rails.logger.info "🔍 Treating identifier as target_user_id"
      target_user = find_user_by_id(identifier)
      unless target_user
        Rails.logger.error "❌ Target user not found: #{identifier}"
        return nil
      end

      Rails.logger.info "🔍 Target user found: #{target_user.id} - #{target_user.name}"

      if ensure_room
        Rails.logger.info "🔍 Creating/finding direct room"
        room = GcInternalChatRoom.find_or_create_direct_room(
          Current.account,
          Current.user,
          target_user
        )
      else
        Rails.logger.info "🔍 Finding existing direct room"
        user_ids = [Current.user.id, target_user.id].sort
        direct_key = "#{user_ids.join('-')}"
        room = Current.account.gc_internal_chat_rooms.find_by(room_type: :direct, direct_key: direct_key)
      end

      unless room
        Rails.logger.error "❌ Direct room not found or created"
        return nil
      end

      Rails.logger.info "🔍 Direct room resolved: #{room.id} - #{room.name}"
      { room: room, chat_id: target_user.id }
    else
      Rails.logger.error "❌ Unknown room type: #{room_type}"
      nil
    end
  end

  def serialize_message(message, chat_type:, chat_id:, room:)
    message_id = value_from_record(message, :id)
    content = value_from_record(message, :content)
    sender_id = value_from_record(message, :sender_id)
    created_at = value_from_record(message, :created_at)
    created_at = Time.zone.parse(created_at.to_s) unless created_at.is_a?(Time)

    sender = sender_payload_for(sender_id)

    {
      id: message_id,
      content: content,
      sender:
        sender,
      sender_id: sender[:id],
      created_at: created_at&.iso8601,
      message_type: 'text',
      chat_type: chat_type,
      chat_id: chat_id,
      room_id: room.id
    }
  end


  def ensure_dependency(type, relative_path)
    yield
  rescue NameError
    require_dependency Rails.root.join('app', 'GeniusCloud-modify', 'app', type, relative_path).to_s
    yield
  end

  def messages_for_room(room, chat_id:, before_id:, limit:)
    scope = room.gc_internal_chat_messages.order(created_at: :asc)
    scope = scope.where('gc_internal_chat_messages.id < ?', before_id) if before_id.present?

    scope.limit(limit).map do |message|
      serialize_message(message, chat_type: room.room_type, chat_id: chat_id, room: room)
    end
  rescue StandardError => e
    Rails.logger.error "❌ Error loading messages for room #{room.id}: #{e.message}"
    []
  end

  def messages_count_for_room(room)
    sql = ActiveRecord::Base.send(:sanitize_sql_array, [
      'SELECT COUNT(*) FROM gc_internal_chat_messages WHERE account_id = ? AND room_id = ? AND deleted_at IS NULL',
      Current.account.id,
      room.id
    ])

    ActiveRecord::Base.connection.select_value(sql).to_i
  end

  def fetch_messages_for_room(room, chat_id:, before_id:, limit:)
    sql = ActiveRecord::Base.send(:sanitize_sql_array, [
      'SELECT id, content, sender_id, created_at FROM gc_internal_chat_messages WHERE account_id = ? AND room_id = ? AND deleted_at IS NULL',
      Current.account.id,
      room.id
    ])

    sql += ActiveRecord::Base.send(:sanitize_sql_array, [' AND id < ?', before_id]) if before_id.present?
    sql += ActiveRecord::Base.send(:sanitize_sql_array, [' ORDER BY created_at ASC LIMIT ?', limit])

    ActiveRecord::Base.connection.exec_query(sql).map do |row|
      serialize_message(row, chat_type: room.room_type, chat_id: chat_id, room: room)
    end
  end

  def sender_payload_for(user_id)
    return default_sender_payload unless user_id

    row = ActiveRecord::Base.connection.exec_query(
      ActiveRecord::Base.send(:sanitize_sql_array, [
        'SELECT id, name, email FROM users WHERE id = ?',
        user_id
      ])
    ).first

    return default_sender_payload(user_id) unless row

    {
      id: row['id'],
      name: row['name'],
      avatar_url: nil
    }
  rescue => e
    Rails.logger.warn "⚠️ Failed to fetch sender #{user_id}: #{e.message}"
    default_sender_payload(user_id)
  end

  def default_sender_payload(user_id = nil)
    {
      id: user_id,
      name: 'Unknown',
      avatar_url: nil
    }
  end

  def value_from_record(record, key)
    if record.respond_to?(key)
      record.public_send(key)
    elsif record.respond_to?(:[])
      record[key.to_s] || record[key.to_sym]
    end
  end
end
