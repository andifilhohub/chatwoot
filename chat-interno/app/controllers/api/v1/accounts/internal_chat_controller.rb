# frozen_string_literal: true

class Api::V1::Accounts::InternalChatController < Api::V1::Accounts::BaseController
  before_action :ensure_internal_chat_models

  def rooms
    general_room = ensure_general_room

    teams_payload = Current.account.teams.includes(:members).map do |team|
      ensure_team_room(team)
      {
        id: team.id,
        name: team.name,
        type: 'team',
        member_count: team.members.count,
        description: team.description || 'Equipe'
      }
    end

    direct_payload = Current.account.account_users.includes(:user)
                              .where.not(users: { id: Current.user.id })
                              .map do |account_user|
      next unless account_user.user

      user = account_user.user
      status = account_user.availability_status || 'offline'

      {
        id: user.id,
        name: user.name,
        email: user.email,
        avatar_url: user.avatar_url,
        availability_status: status.to_s.downcase,
        last_seen_at: user.last_sign_in_at
      }
    end
                              .compact

    @rooms = {
      general: {
        id: 'general',
        name: general_room.name,
        type: general_room.room_type,
        description: general_room.metadata&.dig('description') || 'Conversas gerais da equipe'
      },
      teams: teams_payload,
      direct_messages: direct_payload
    }

    Rails.logger.info "🏠 Rooms loaded for account #{Current.account.id}: #{@rooms.keys}"
  end

  def create_room
    room_params = params.require(:room)
    room_type = room_params[:room_type]
    target_user_id = room_params[:target_user_id]

    Rails.logger.info "🆕 Creating room: #{room_type} for user #{target_user_id}"

    if room_type == 'direct'
      # Check if room already exists between these users
      existing_room = Current.account.gc_internal_chat_rooms
                             .joins(:memberships)
                             .where(room_type: 'direct')
                             .where(memberships: { user_id: [Current.user.id, target_user_id] })
                             .group('gc_internal_chat_rooms.id')
                             .having('COUNT(DISTINCT memberships.user_id) = 2')
                             .first

      if existing_room
        Rails.logger.info "✅ Found existing direct room: #{existing_room.id}"
        @room = existing_room
      else
        # Create new direct room
        direct_key = "direct-#{[Current.user.id, target_user_id].sort.join('-')}"
        @room = Current.account.gc_internal_chat_rooms.create!(
          room_type: 'direct',
          name: "Direct Chat",
          slug: direct_key,
          direct_key: direct_key
        )
        
        # Add memberships (participants)
        @room.memberships.create!(user_id: Current.user.id)
        @room.memberships.create!(user_id: target_user_id)
        
        Rails.logger.info "✅ Created new direct room: #{@room.id}"
      end

      render json: {
        data: {
          id: @room.id,
          type: @room.room_type,
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
    room_type = params[:room_type].to_s
    requested_identifier = params[:room_id]
    before_id = params[:before_id]
    limit = params[:per_page]&.to_i || 50

    Rails.logger.info "📨 Loading messages for #{room_type}/#{requested_identifier}"

    result = resolve_room(room_type, requested_identifier, ensure_room: true)

    unless result
      Rails.logger.warn "❌ Could not resolve room for #{room_type}/#{requested_identifier}"
      return render json: { data: [], meta: { current_page: 1, per_page: limit, total_count: 0, error: 'Room not found' } }
    end

    room = result[:room]
    chat_id = result[:chat_id]

    payload = messages_for_room(room, chat_id: chat_id, before_id: before_id, limit: limit)

    render json: {
      data: payload,
      meta: {
        current_page: 1,
        per_page: limit,
        total_count: messages_count_for_room(room),
        room_id: room.id,
        chat_id: chat_id
      }
    }
  end

  def messages_general
    params[:room_type] = 'general'
    params[:room_id] = 'general'
    messages
  end

  def send_message
    message_params = extract_message_params


    if message_params[:content].blank? && message_params[:attachments].blank?
      return render json: { errors: ['Message cannot be blank'] }, status: :unprocessable_entity
    end

    result = resolve_room(message_params[:room_type], message_params[:room_id], ensure_room: true)

    unless result
      return render json: { errors: ['Room not found'] }, status: :not_found
    end

    room = result[:room]
    chat_id = result[:chat_id]

    begin
      builder = ::GeniusCloud::InternalChat::MessageBuilder.new(
        room: room,
        sender: Current.user,
        params: {
          content: message_params[:content],
          attachments: message_params[:attachments],
          metadata: message_params[:metadata] || {}
        }
      )

      message = builder.create!
    rescue => e
      return render json: { errors: ["Error creating message: #{e.message}"] }, status: :unprocessable_entity
    end

    serialized = serialize_message(message, chat_type: room.room_type, chat_id: chat_id, room: room)

    broadcast_data = {
      type: 'new_message',
      chat_type: room.room_type,
      chat_id: chat_id,
      message: serialized,
      timestamp: message.created_at.iso8601
    }

    Rails.logger.info "📡 Broadcasting message to internal_chat_#{Current.account.id}"
    Rails.logger.info "📡 Broadcast data: #{broadcast_data.inspect}"

    ActionCable.server.broadcast(
      "internal_chat_#{Current.account.id}",
      broadcast_data
    )

    Rails.logger.info "📡 Message broadcasted successfully"

    render json: { data: serialized }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "❌ Failed to send message: #{e.message}"
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  private

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
    ensure_dependency('models', 'genius_cloud/internal_chat/room') { GeniusCloud::InternalChat::Room }
    ensure_dependency('models', 'genius_cloud/internal_chat/message') { GeniusCloud::InternalChat::Message }
    ensure_dependency('models', 'genius_cloud/internal_chat/membership') { GeniusCloud::InternalChat::Membership }
    ensure_dependency('services', 'genius_cloud/internal_chat/message_builder') { GeniusCloud::InternalChat::MessageBuilder }
    ensure_dependency('services', 'genius_cloud/internal_chat/direct_room_builder') { GeniusCloud::InternalChat::DirectRoomBuilder }
  end

  def ensure_general_room
    ::GeniusCloud::InternalChat::Room.ensure_general!(Current.account)
  end

  def ensure_team_room(team)
    ::GeniusCloud::InternalChat::Room.ensure_team!(team)
  end

  def resolve_room(room_type, identifier, ensure_room: false)
    case room_type.to_s
    when 'general'
      room = ensure_general_room
      { room: room, chat_id: 'general' }
    when 'team'
      team = Current.account.teams.find_by(id: identifier)
      return nil unless team

      room = ensure_team_room(team)

      { room: room, chat_id: team.id }
    when 'direct'
      target_user = find_user_by_id(identifier)
      return nil unless target_user

      if ensure_room
        room = ::GeniusCloud::InternalChat::DirectRoomBuilder.new(
          account: Current.account,
          initiating_user: Current.user,
          target_user: target_user
        ).find_or_create
      else
        user_ids = [Current.user.id, target_user.id].sort
        direct_key = "direct-#{user_ids.join('-')}"
        room = Current.account.gc_internal_chat_rooms.find_by(room_type: :direct, direct_key: direct_key)
      end

      return nil unless room

      { room: room, chat_id: target_user.id }
    else
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
    attachments = attachments_payload_for(message)
    message_type = attachments.present? && content.to_s.strip.blank? ? 'attachment' : 'text'

    {
      id: message_id,
      content: content,
      sender:
        sender,
      sender_id: sender[:id],
      created_at: created_at&.iso8601,
      message_type: message_type,
      chat_type: chat_type,
      chat_id: chat_id,
      room_id: room.id,
      attachments: attachments
    }
  end

  def extract_message_params
    # Usar to_unsafe_h para acessar todos os parâmetros, incluindo attachments
    if params[:message].present?
      message_params = params[:message].to_unsafe_h
      payload = {
        content: message_params[:content],
        room_type: message_params[:room_type],
        room_id: message_params[:room_id],
        message_type: message_params[:message_type],
        metadata: message_params[:metadata] || {}
      }
      
      # Processar attachments do FormData - tentar diferentes localizações
      attachments = []
      
      # Tentar params[:message][:attachments]
      if message_params[:attachments]
        attachments = Array(message_params[:attachments]).select(&:present?)
      end
      
      # Tentar params[:attachments] diretamente
      if attachments.empty? && params[:attachments]
        attachments = Array(params[:attachments]).select(&:present?)
      end
      
      # Tentar buscar em todos os parâmetros
      if attachments.empty?
        all_params = params.to_unsafe_h
        all_params.each do |key, value|
          if key.to_s.include?('attachment') && value.is_a?(Array)
            attachments = Array(value).select(&:present?)
            break
          end
        end
      end
      
      payload[:attachments] = attachments
    else
      payload = params.permit(:content, :room_type, :room_id, :message_type, attachments: [], metadata: {}).to_h
    end

    payload[:room_type] = payload[:room_type].to_s
    payload
  end

  def ensure_dependency(type, relative_path)
    yield
  rescue NameError
    # GeniusCloud-modify directory was removed
    raise NameError, "Required dependency not found: #{type}/#{relative_path}"
  end

  def messages_for_room(room, chat_id:, before_id:, limit:)
    scope = room.messages.active.order(created_at: :asc)
    scope = scope.where('gc_internal_chat_messages.id < ?', before_id) if before_id.present?
    messages = scope.limit(limit)
    
    messages.map do |message|
      serialize_message(message, chat_type: room.room_type, chat_id: chat_id, room: room)
    end
  rescue ActiveRecord::SubclassNotFound => e
    fetch_messages_for_room(room, chat_id: chat_id, before_id: before_id, limit: limit)
  rescue => e
    []
  end

  def messages_count_for_room(room)
    conditions = [
      ActiveRecord::Base.send(:sanitize_sql_array, ['account_id = ?', Current.account.id]),
      ActiveRecord::Base.send(:sanitize_sql_array, ['room_id = ?', room.id]),
      'deleted_at IS NULL'
    ]

    sql = <<~SQL
      SELECT COUNT(*)
      FROM gc_internal_chat_messages
      WHERE #{conditions.join(' AND ')}
    SQL

    ActiveRecord::Base.connection.select_value(sql).to_i
  end

  def fetch_messages_for_room(room, chat_id:, before_id:, limit:)
    conditions = [
      ActiveRecord::Base.send(:sanitize_sql_array, ['account_id = ?', Current.account.id]),
      ActiveRecord::Base.send(:sanitize_sql_array, ['room_id = ?', room.id]),
      'deleted_at IS NULL'
    ]
    if before_id.present?
      conditions << ActiveRecord::Base.send(:sanitize_sql_array, ['id < ?', before_id])
    end

    sql = <<~SQL
      SELECT id, content, sender_id, created_at
      FROM gc_internal_chat_messages
      WHERE #{conditions.join(' AND ')}
      ORDER BY created_at ASC
      LIMIT #{limit.to_i}
    SQL

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

  def attachments_payload_for(record)
    target_id = value_from_record(record, :id)
    return [] if target_id.blank?

    attachments = if record.respond_to?(:files) && record.files.respond_to?(:attachments)
                     record.files.attachments.includes(:blob)
                   else
                     ActiveStorage::Attachment
                       .includes(:blob)
                       .where(
                         record_type: 'GeniusCloud::InternalChat::Message',
                         record_id: target_id,
                         name: 'files'
                       )
                   end

    attachments.map do |attachment|
      blob = attachment.blob

      {
        id: attachment.id,
        filename: blob.filename.to_s,
        byte_size: blob.byte_size,
        content_type: blob.content_type,
        url: Rails.application.routes.url_helpers.rails_blob_path(attachment, only_path: true)
      }
    end
  end

  def attachment_payload(attachment)
    return {} unless attachment.file.attached?

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
  end
end
