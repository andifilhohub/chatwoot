require 'securerandom'
require 'uri'
require 'base64'
require 'openssl'
class Public::Api::V1::Zaphub::CallbacksController < PublicController
  before_action :find_channel
  before_action :verify_zaphub_webhook_signature, only: [:create]

  def create
    # Log do JSON completo exatamente como recebido do Zaphub
    body_content = raw_request_body

    Rails.logger.info '[Zaphub] JSON completo recebido do webhook:'
    Rails.logger.info body_content

    process_webhook_payload
    head :ok
  rescue StandardError => e
    Rails.logger.error "ZapHub webhook error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    head :unprocessable_entity
  end

  private

  def find_channel
    channel_id = params[:channel_id]
    @channel = Channel::Zaphub.find_by(id: channel_id)
    @inbox = @channel&.inbox

    if @channel.nil? || @inbox.nil?
      inbox = Inbox.find_by(id: channel_id, channel_type: Channel::Zaphub.name) ||
              Inbox.find_by(channel: @channel) ||
              Inbox.find_by(channel_id: @channel&.id)

      if inbox
        @channel = inbox.channel
        @inbox = inbox
        Rails.logger.warn("[Zaphub] webhook referenced inbox #{channel_id}, falling back to linked channel #{@channel&.id}")
      end
    end

    unless @channel
      Rails.logger.warn("[Zaphub] webhook received for unknown channel #{channel_id}")
      head :not_found
      return
    end

    unless @inbox
      Rails.logger.warn("[Zaphub] webhook received for channel #{@channel.id} without inbox; rejecting webhook")
      head :not_found
      return
    end
  end

  def verify_zaphub_webhook_signature
    return if @channel.blank?

    secret = zaphub_webhook_signature_secret
    return if secret.blank?

    signature_header = request.headers['X-ZapHub-Signature'] || request.headers['HTTP_X_ZAPHUB_SIGNATURE']

    return if valid_zaphub_signature?(signature_header, secret)

    Rails.logger.warn("[Zaphub] Invalid webhook signature for channel #{@channel.id}")
    head :unauthorized
    return
  end

  def valid_zaphub_signature?(signature_header, secret)
    return false if signature_header.blank?

    payload = raw_request_body.to_s
    digest = OpenSSL::HMAC.digest(OpenSSL::Digest.new('SHA256'), secret, payload)
    expected_hex = digest.unpack1('H*')
    expected_base64 = Base64.strict_encode64(digest)
    expected_base64_urlsafe = Base64.urlsafe_encode64(digest)

    header_value = signature_from_header(signature_header)
    return false if header_value.blank?

    log_signature_debug(header_value, expected_hex, expected_base64, expected_base64_urlsafe)

    return true if compare_hex_signature(expected_hex, header_value)
    return true if compare_base64_signature(expected_base64, expected_base64_urlsafe, header_value)

    false
  rescue StandardError => e
    Rails.logger.warn("[Zaphub] Failed to verify webhook signature for channel #{@channel&.id}: #{e.message}")
    false
  end

  def signature_from_header(signature_header)
    value = signature_header.to_s.strip
    return '' if value.blank?

    # Preserve padding when signature is raw Base64 (e.g. ends with "=")
    return value unless value.downcase.start_with?('sha256=')

    value.split('=', 2).last.to_s.strip
  end

  def compare_hex_signature(expected, actual)
    normalized_actual = actual.to_s.downcase
    return false unless normalized_actual.length == expected.length

    ActiveSupport::SecurityUtils.secure_compare(expected, normalized_actual)
  end

  def compare_base64_signature(expected, expected_urlsafe, actual)
    return false unless actual.present?

    normalized_actual = normalize_base64(actual)

    normalized_expected = normalize_base64(expected)
    normalized_expected_urlsafe = normalize_base64(expected_urlsafe)

    return true if normalized_actual.length == normalized_expected.length &&
                   ActiveSupport::SecurityUtils.secure_compare(normalized_expected, normalized_actual)

    return true if normalized_actual.length == normalized_expected_urlsafe.length &&
                   ActiveSupport::SecurityUtils.secure_compare(normalized_expected_urlsafe, normalized_actual)

    false
  end

  def normalize_base64(value)
    normalized = value.to_s.tr('-_', '+/')
    padding = (4 - (normalized.length % 4)) % 4
    normalized.ljust(normalized.length + padding, '=')
  end

  def log_signature_debug(header_value, expected_hex, expected_base64, expected_base64_urlsafe)
    return unless Rails.env.development? || Rails.env.test?

    Rails.logger.info("[Zaphub] Signature debug | header=#{header_value} | expected_hex=#{expected_hex} | " \
                      "expected_b64=#{expected_base64} | expected_b64_urlsafe=#{expected_base64_urlsafe}")
  end

  def process_webhook_payload
    event_type = zaphub_event_type
    log_zaphub_webhook(event_type)

    if event_type.blank?
      Rails.logger.info 'Unhandled ZapHub event type: (missing)'
      return
    end

    case event_type
    when 'message', 'message.received', 'message.sent', 'message.outgoing', 'message.incoming'
      process_message_event(event_type)
    when 'presence', 'presence.update'
      process_presence_event
    when 'receipt', 'message.delivered', 'message.read', 'message.update', 'message.receipt.update', 'message-receipt.update',
         'message.receipt.read', 'message.receipt.delivered', 'message.receipt.sent'
      process_receipt_event(event_type)
    when 'reaction', 'message.reaction'
      process_reaction_event
    when 'message.edited'
      process_message_edited_event
    when 'message.deleted'
      process_message_deleted_event
    when 'call', 'call.offer', 'call.accept', 'call.reject', 'call.timeout', 'call.terminate'
      process_call_event
    when 'group', 'group.participants.add', 'group.participants.remove', 'group.participants.promote', 'group.participants.demote', 'group.update'
      process_group_event
    when 'contact', 'contact.upsert', 'contacts.upsert'
      process_contact_upsert_event
    else
      Rails.logger.info "Unhandled ZapHub event type: #{event_type}"
    end
  end

  def log_zaphub_webhook(event_type)
    payload = raw_zaphub_payload
    message_data = payload[:data].is_a?(Hash) ? payload[:data] : payload
    direction = message_data[:direction] || message_data[:status]
    message_id = message_data[:messageId] || message_data[:message_id]
    Rails.logger.info "🔔 ZapHub webhook | event=#{event_type.presence || 'unknown'} | direction=#{direction || 'n/a'} | message_id=#{message_id || 'n/a'} | payload=#{payload.to_json}"
  rescue StandardError => e
    Rails.logger.warn "⚠️ Failed to log ZapHub webhook: #{e.message}"
  end

  def process_message_event(event_type = nil)
    message_data = zaphub_payload
    return if message_data.blank?

    sent_by_us = message_sent_by_us?(message_data, event_type)
    message_identifier = extract_message_identifier(message_data)
    wa_message_identifier = extract_wa_message_identifier(message_data)

    if sent_by_us && (message_identifier.present? || wa_message_identifier.present?)
      existing_message = find_message_by_identifier(message_identifier) if message_identifier.present?
      existing_message ||= find_message_by_identifier(wa_message_identifier) if wa_message_identifier.present?
      return existing_message if handle_existing_outgoing_message(existing_message, message_identifier, wa_message_identifier, message_data,
                                                                  event_type)
    end

    sender_identifier = message_sender_identifier(message_data, sent_by_us)
    chat_identifier = message_chat_identifier(message_data, sent_by_us, sender_identifier)

    contact_inbox = find_or_create_contact_inbox(message_data, sent_by_us, chat_identifier, sender_identifier)
    return if contact_inbox.blank?

    contact = contact_inbox.contact
    conversation = find_or_create_conversation(contact_inbox, contact, message_data, sent_by_us, chat_identifier)

    message = if sent_by_us
                find_existing_outgoing_message(conversation, message_data) || create_message(conversation, contact, message_data, sent_by_us)
              else
                create_message(conversation, contact, message_data, sent_by_us)
              end
    send_zaphub_received_event(message, message_data) unless sent_by_us
  end

  def find_or_create_contact_inbox(message_data, _sent_by_us, chat_identifier, sender_identifier)
    unless @inbox.present?
      Rails.logger.warn("[Zaphub] Cannot create/find contact_inbox because inbox is nil (channel_id=#{@channel&.id})")
      return nil
    end

    phone_number = extract_phone_number(sender_identifier)

    is_group = group_chat?(message_data)
    group_name = message_data[:groupName] || message_data[:groupSubject] || message_data[:subject]
    contact_name = if is_group
                     group_name || message_data[:chatName] || message_data[:pushName] || sender_identifier
                   else
                     message_data[:chatName] || message_data[:pushName] || message_data[:name] || phone_number || sender_identifier
                   end
    avatar_url = if is_group
                   message_data[:groupImageUrl] || message_data[:chatImageUrl]
                 else
                   message_data[:contactImageUrl] || message_data[:chatImageUrl]
                 end

    contact_inbox = ContactInboxWithContactBuilder.new(
      inbox: @inbox,
      source_id: chat_identifier,
      hmac_verified: true,
      contact_attributes: {
        name: contact_name,
        phone_number: phone_number,
        identifier: chat_identifier,
        avatar_url: avatar_url,
        additional_attributes: {
          source: 'zaphub',
          raw: message_data
        }
      }
    ).perform
    update_contact_avatar_zaphub(contact_inbox&.contact, avatar_url)
    contact_inbox
  end

  def find_or_create_conversation(contact_inbox, contact, _message_data, _sent_by_us, chat_identifier)
    conversation = if @inbox.lock_to_single_conversation
                     contact_inbox.conversations.last
                   else
                     contact_inbox.conversations.where.not(status: :resolved).last
                   end

    return conversation if conversation

    Conversation.create!(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      contact_id: contact.id,
      contact_inbox_id: contact_inbox.id,
      additional_attributes: {
        source: 'zaphub',
        chat_id: chat_identifier
      }
    )
  end

  def find_existing_outgoing_message(conversation, message_data)
    message_identifier = message_data[:id] || message_data[:messageId] || message_data[:message_id] || message_data[:waMessageId]
    text_payload = message_data[:text] || message_data.dig(:content, :text)

    scope = conversation.messages.outgoing.order(created_at: :desc)
                       .where('created_at >= ?', 10.minutes.ago)
                       .where("source_id IS NULL OR source_id LIKE 'msg-%' OR external_source_ids ->> 'zaphub' IS NULL")

    scope = scope.where(content: text_payload) if text_payload.present?

    existing = scope.first
    return unless existing

    attrs = {
      source_id: message_identifier.presence || existing.source_id,
      external_source_ids: (existing.external_source_ids || {}).merge('zaphub' => message_identifier.presence || existing.source_id)
    }

    status = normalize_outgoing_status(message_data[:status])
    attrs[:status] = status if status.present? && existing.status != status

    existing.update!(attrs)
    Rails.logger.info "[Zaphub] Matched outgoing message #{existing.id} to messageId #{message_identifier}"
    existing
  rescue StandardError => e
    Rails.logger.warn "[Zaphub] Failed to match outgoing message for payload=#{message_data.inspect}: #{e.message}"
    nil
  end

  def normalize_outgoing_status(raw_status)
    return if raw_status.blank?

    val = raw_status.to_s.downcase
    return 'read' if val == 'read'
    return 'delivered' if val == 'delivered'
    return 'sent' if val == 'sent'
  end

  def create_message(conversation, contact, message_data, sent_by_us = false)
    message_identifier = message_data[:id] || message_data[:messageId] || message_data[:message_id]
    message_identifier ||= SecureRandom.uuid
    content = extract_message_content(message_data)
    content = '[Unsupported message]' if content.blank?

    # Build content_attributes with whatsapp_message_type
    content_attrs = {}
    message_type = message_data[:type]
    if message_type.present?
      # Map WhatsApp message types to our format
      whatsapp_type = case message_type
                      when 'contact' then 'contactMessage'
                      when 'location' then 'locationMessage'
                      when 'image' then 'imageMessage'
                      when 'video' then 'videoMessage'
                      when 'audio' then 'audioMessage'
                      when 'document' then 'documentMessage'
                      else nil
                      end
      content_attrs[:whatsapp_message_type] = whatsapp_type if whatsapp_type
    end

    message_params = {
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      message_type: sent_by_us ? :outgoing : :incoming,
      conversation_id: conversation.id,
      sender: sent_by_us ? nil : contact,
      content: content,
      source_id: message_identifier,
      external_source_id_zaphub: message_identifier,
      content_attributes: content_attrs
    }

    attachments = process_attachments(message_data)

    message = Message.new(message_params)

    # Attach files before saving to ensure tempfiles are still open
    if attachments.present?
      attach_downloaded_files(message, attachments)
      # Reload to ensure attachments are properly associated
      message.attachments.reload if message.persisted?
    end

    message.save!

    # Verify attachments were saved correctly
    if message.attachments.present?
      message.attachments.each do |att|
        Rails.logger.error "[Zaphub] Attachment #{att.id} file not attached after save!" unless att.file.attached?
      end
      log_attachment_urls(message)
    end

    message
  end

  def send_zaphub_received_event(message, message_data)
    return unless message&.inbox&.channel_type == 'Channel::Zaphub'

    event_data = {}
    event_data[:content] = { text: message.content } if message.content.present?
    event_data[:receivedAt] = message_data[:timestamp] if message_data[:timestamp].present?

    # ZapHub API only accepts message.edited, message.deleted, message.sent, message.delivered, message.read, message.failed
    Zaphub::EventService.new(message: message, event: 'message.delivered', data: event_data).perform
  end

  def extract_message_content(message_data)
    case message_data[:type]
    when 'text'
      message_data[:text] || message_data.dig(:content, :text)
    when 'image'
      message_data.dig(:image, :caption) || message_data.dig(:content, :caption) || '[Image]'
    when 'video'
      message_data.dig(:video, :caption) || message_data.dig(:content, :caption) || '[Video]'
    when 'audio'
      message_data.dig(:content, :caption) || '[Audio message]'
    when 'document'
      message_data.dig(:document, :fileName) || message_data.dig(:content, :fileName) || '[Document]'
    when 'location'
      location = message_data[:location] || message_data[:content] || {}
      "📍 Location: #{location[:name] || 'Shared location'}\nLat: #{location[:latitude]}, Long: #{location[:longitude]}"
    when 'contact'
      "👤 Contact: #{message_data.dig(:contact, :displayName) || message_data.dig(:content, :displayName)}"
    else
      message_data.dig(:content, :text) || "[#{message_data[:type] || 'unknown'} message]"
    end
  end

  def process_attachments(message_data)
    return [] if message_data.blank?

    original_file_name = dedupe_file_name(message_data)
    type = message_data[:type].presence || 'document'

    Rails.logger.info "[Zaphub] Processing attachment: type=#{type}, filename=#{original_file_name}, raw_media=#{message_data[:raw_media].inspect}"

    attachment = Zaphub::MediaAttachmentService.new(
      message_data: message_data,
      type: type,
      file_name: original_file_name,
      request: request
    ).call

    if attachment
      Rails.logger.info "[Zaphub] Attachment processed successfully: filename=#{attachment[:filename]}, content_type=#{attachment[:content_type]}"
      [attachment]
    else
      Rails.logger.warn "[Zaphub] Attachment processing returned nil for type=#{type}"
      []
    end
  end

  def dedupe_file_name(message_data)
    original = message_data.dig(:content, :fileName)
    return original if original.present?

    fallback = message_data.dig(:document, :fileName)
    return fallback if fallback.present?

    nil
  end

  def attach_downloaded_files(message, attachments)
    attachments.each do |data|
      next if data.blank?

      file_io = data[:io]
      filename = data[:filename] || 'attachment'
      content_type = data[:content_type] || 'application/octet-stream'
      file_type = data[:file_type] || 'file'

      # Ensure file is open and readable
      if file_io.respond_to?(:rewind)
        file_io.rewind
      elsif file_io.respond_to?(:closed?) && file_io.closed?
        Rails.logger.error '[Zaphub] attachment file_io is closed, cannot attach'
        next
      end

      # Verify file_io is readable
      unless file_io.respond_to?(:read)
        Rails.logger.error '[Zaphub] file_io does not respond to :read'
        next
      end

      attachment = message.attachments.build(account_id: message.account_id, file_type: file_type)

      # Attach the file - ActiveStorage will read immediately
      begin
        # Ensure file is at the beginning
        file_io.rewind if file_io.respond_to?(:rewind)

        attachment.file.attach(io: file_io, filename: filename, content_type: content_type)

        # Save the message to persist the attachment
        message.save! unless message.persisted?

        # Reload to get the persisted blob
        attachment.reload if attachment.persisted?

        # Verify attachment was successful
        if attachment.file.attached?
          blob = attachment.file.blob
          Rails.logger.info "[Zaphub] Successfully attached file: filename=#{filename}, content_type=#{content_type}, blob_id=#{blob.id}, size=#{blob.byte_size}, content_type_stored=#{blob.content_type}"
        else
          Rails.logger.error "[Zaphub] File attach failed: filename=#{filename}, content_type=#{content_type}"
        end
      rescue StandardError => e
        Rails.logger.error "[Zaphub] Failed to attach file: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        next
      end
    rescue StandardError => e
      Rails.logger.error "[Zaphub] Failed to persist ZapHub attachment: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end

  def extract_phone_number(jid)
    identifier = jid.to_s
    return if identifier.blank?

    number_part = identifier.split('@').first
    number_part = number_part.split(':').first if number_part.include?(':')
    return if number_part.blank?

    # Group chats contain a hyphen separating owner/timestamp
    return if number_part.include?('-')

    digits = number_part.gsub(/\D/, '')
    return if digits.blank?

    normalized = "+#{digits}"
    return normalized if normalized.match?(/\A\+[1-9]\d{1,14}\z/)

    nil
  end

  def process_presence_event
    Rails.logger.info "ZapHub presence event: #{zaphub_payload}"
  end

  def process_receipt_event(event_type)
    payload = zaphub_payload
    Rails.logger.info "[Zaphub] Processing receipt event: event_type=#{event_type}, payload=#{payload.inspect}"

    # Zaphub can send receipts as an array or as a single object
    # Also check if data contains the receipt info
    receipts = Array.wrap(payload[:receipts])
    receipts = Array.wrap(payload[:data][:receipts]) if receipts.blank? && payload[:data].is_a?(Hash)
    receipts = [payload] if receipts.blank?
    receipts = [payload[:data]] if receipts.blank? && payload[:data].is_a?(Hash)

    Rails.logger.info "[Zaphub] Found #{receipts.length} receipt(s) to process"

    receipts.each do |receipt_payload|
      apply_receipt_status(receipt_payload, event_type)
    end
  end

  def apply_receipt_status(payload, fallback_event)
    # Extract messageId from various possible locations (including waMessageId)
    message_id = extract_message_identifier(payload)
    wa_message_id = extract_wa_message_identifier(payload)

    Rails.logger.info "[Zaphub] Processing receipt status: message_id=#{message_id}, payload=#{payload.inspect}, fallback_event=#{fallback_event}"

    return if message_id.blank? && wa_message_id.blank?

    # Try to find by source_id first, then by external_source_id_zaphub
    message = find_message_by_identifier(message_id)
    message ||= find_message_by_identifier(wa_message_id)
    unless message
      Rails.logger.warn "[Zaphub] Message not found for receipt: message_id=#{message_id || wa_message_id}"
      return
    end

    raw_status = (payload[:status] || payload[:type] || fallback_event).to_s
    normalized_status = normalize_status(raw_status, fallback_event)

    Rails.logger.info "[Zaphub] Updating message #{message.id} status from #{message.status} to #{normalized_status} (raw: #{raw_status})"

    case normalized_status
    when 'read'
      Messages::StatusUpdateService.new(message, 'read').perform
      enqueue_conversation_status_job(message, payload, :read)
    when 'delivered'
      Messages::StatusUpdateService.new(message, 'delivered').perform unless message.read?
      enqueue_conversation_status_job(message, payload, :delivered)
    when 'sent'
      Messages::StatusUpdateService.new(message, 'sent').perform unless message.read? || message.delivered?
    else
      Rails.logger.warn "[Zaphub] Unknown receipt status: #{normalized_status} (raw: #{raw_status})"
    end
  end

  def find_message_by_identifier(message_id)
    return nil if message_id.blank?

    Message.find_by(source_id: message_id) ||
      Message.find_by("external_source_ids ->> 'zaphub' = ?", message_id) ||
      Message.find_by("external_source_ids ->> 'zaphub_wa' = ?", message_id)
  end

  def extract_message_identifier(payload)
    wa_id = extract_wa_message_identifier(payload)
    msg_id = payload[:messageId] || payload[:message_id] || payload[:id] || payload.dig(:data, :messageId)
    wa_id.presence || msg_id
  end

  def extract_wa_message_identifier(payload)
    payload[:waMessageId] || payload[:wa_message_id] || payload.dig(:data, :waMessageId)
  end

  def extract_status_from_event_name(event_name)
    return nil if event_name.blank?

    event_str = event_name.to_s.downcase
    return 'read' if event_str.include?('receipt.read') || event_str.include?('message.read')
    return 'delivered' if event_str.include?('receipt.delivered') || event_str.include?('message.delivered')
    return 'sent' if event_str.include?('receipt.sent') || event_str.include?('message.sent')

    nil
  end

  def normalize_status(raw_status, fallback_event)
    raw = (raw_status || extract_status_from_event_name(fallback_event) || fallback_event).to_s.downcase

    return 'read' if raw.include?('receipt.read') || raw == 'read' || raw == 'message.read'
    return 'delivered' if raw.include?('receipt.delivered') || raw == 'delivered' || raw == 'message.delivered'
    return 'sent' if raw.include?('receipt.sent') || raw == 'sent' || raw == 'message.sent'
    return 'received' if raw == 'received' || raw == 'message.received'

    raw
  end

  def handle_existing_outgoing_message(existing_message, message_identifier, wa_message_identifier, message_data, event_type)
    return false unless existing_message

    backfill_message_identifier(existing_message, message_identifier, wa_message_identifier)
    update_message_status_from_payload(existing_message, message_data, event_type)
    true
  end

  def backfill_message_identifier(message, message_identifier, wa_message_identifier = nil)
    return if message_identifier.blank? && wa_message_identifier.blank?

    source_value = message.source_id.presence || message_identifier || wa_message_identifier
    new_external_ids = message.external_source_ids || {}

    new_external_ids['zaphub'] ||= (message.external_source_id_zaphub.presence || message_identifier)
    new_external_ids['zaphub_wa'] ||= wa_message_identifier if wa_message_identifier.present?

    message.update_columns(
      source_id: source_value,
      external_source_ids: new_external_ids
    )
  end

  def fallback_outgoing_message(payload, message_identifier, wa_message_identifier)
    chat_identifier = message_chat_identifier(payload, true, nil)
    return nil if chat_identifier.blank? || @inbox.blank?

    conversation = Conversation.where(inbox_id: @inbox.id)
                               .where("additional_attributes ->> 'chat_id' = ?", chat_identifier)
                               .order(created_at: :desc)
                               .take
    return nil unless conversation

    conversation.messages
                .where(message_type: :outgoing)
                .where(source_id: [nil, message_identifier, wa_message_identifier].compact_blank)
                .where("external_source_ids ->> 'zaphub' IS NULL OR external_source_ids ->> 'zaphub' = ?", message_identifier.to_s)
                .order(created_at: :desc)
                .take
  end

  def update_message_status_from_payload(message, message_data, fallback_event)
    normalized_status = normalize_status(message_data[:status] || message_data[:type], fallback_event)
    return if normalized_status.blank?

    if %w[read delivered sent].include?(normalized_status)
      Messages::StatusUpdateService.new(message, normalized_status).perform
      Rails.logger.info "[Zaphub] Updated message #{message.id} status to #{normalized_status} from webhook event #{fallback_event}"
    elsif normalized_status == 'received' && message.outgoing?
      # Treat 'received' from ZapHub as delivered for outbound messages
      Messages::StatusUpdateService.new(message, 'delivered').perform
      Rails.logger.info "[Zaphub] Updated message #{message.id} status to delivered (from 'received') via webhook event #{fallback_event}"
    end
  end

  def process_reaction_event
    Rails.logger.info "ZapHub reaction event: #{zaphub_payload}"
  end

  def process_message_edited_event
    payload = zaphub_payload
    data = payload[:data] || payload

    message_id = data[:messageId] || data[:message_id] || data[:id]
    return if message_id.blank?

    Rails.logger.info "[Zaphub] Processing message edited event: message_id=#{message_id}"

    message = find_message_by_identifier(message_id)
    unless message
      Rails.logger.warn "[Zaphub] Message not found for edit: message_id=#{message_id}"
      return
    end

    # Extract new content from payload
    new_content = data.dig(:content, :text) || data[:content] || data[:text]
    return if new_content.blank?

    # Update message content
    message.update!(content: new_content)
    Rails.logger.info "[Zaphub] Message #{message.id} content updated successfully"
  end

  def process_message_deleted_event
    payload = zaphub_payload
    data = payload[:data] || payload

    message_id = data[:messageId] || data[:message_id] || data[:id]
    return if message_id.blank?

    Rails.logger.info "[Zaphub] Processing message deleted event: message_id=#{message_id}"

    message = find_message_by_identifier(message_id)
    unless message
      Rails.logger.warn "[Zaphub] Message not found for delete: message_id=#{message_id}"
      return
    end

    # Mark message as deleted
    ActiveRecord::Base.transaction do
      message.update!(
        content: I18n.t('conversations.messages.deleted'),
        content_type: :text,
        content_attributes: message.content_attributes.merge(deleted: true)
      )
      message.attachments.destroy_all
    end

    Rails.logger.info "[Zaphub] Message #{message.id} marked as deleted successfully"
  end

  def process_call_event
    Rails.logger.info "ZapHub call event: #{zaphub_payload}"
  end

  def process_group_event
    Rails.logger.info "ZapHub group event: #{zaphub_payload}"
  end

  def find_message_by_zaphub_ids(*ids)
    candidate_ids = ids.compact_blank
    return nil if candidate_ids.blank?

    Message.where(source_id: candidate_ids)
           .or(Message.where("external_source_ids ->> 'zaphub' IN (?)", candidate_ids))
           .first
  end

  def enqueue_conversation_status_job(message, payload, status)
    return unless message&.conversation_id.present?
    return unless %i[read delivered].include?(status)

    timestamp = receipt_timestamp(payload) || message.created_at
    ::Conversations::UpdateMessageStatusJob.perform_later(message.conversation_id, timestamp, status)
  end

  def receipt_timestamp(payload)
    ts = payload[:readAt] || payload[:deliveredAt] || payload[:timestamp]
    ts = ts.to_i if ts.respond_to?(:to_i) && ts.to_s.match?(/\A\d+\z/)
    Time.parse(ts.to_s) if ts.present?
  rescue StandardError => e
    Rails.logger.warn "[Zaphub] Failed to parse receipt timestamp #{ts.inspect}: #{e.message}"
    nil
  end

  def process_contact_upsert_event
    payload = raw_zaphub_payload
    contacts = Array.wrap(payload[:contacts] || payload.dig(:data, :contacts))

    if contacts.blank?
      Rails.logger.info '[Zaphub] contact.upsert received with no contacts'
      return
    end

    unless @inbox.present?
      Rails.logger.warn("[Zaphub] contact.upsert ignored because inbox is nil (channel_id=#{@channel&.id})")
      return
    end

    contacts.each do |contact_payload|
      jid = contact_payload[:jid] || contact_payload[:lid] || contact_payload[:id]
      next if jid.blank?

      phone_number = extract_phone_number(jid)
      contact_name = contact_payload[:name] || contact_payload[:pushName] || phone_number || jid
      avatar_url = contact_payload[:imgUrl] || contact_payload[:imageUrl]

      contact_inbox = ContactInboxWithContactBuilder.new(
        inbox: @inbox,
        source_id: jid,
        hmac_verified: true,
        contact_attributes: {
          name: contact_name,
          phone_number: phone_number,
          identifier: jid,
          avatar_url: avatar_url,
          additional_attributes: {
            source: 'zaphub',
            raw: contact_payload
          }
        }
      ).perform
      update_contact_avatar_zaphub(contact_inbox&.contact, avatar_url)
    end
  end

  def update_contact_avatar_zaphub(contact, avatar_url)
    return unless contact.present?
    return if avatar_url.blank?

    ::Avatar::AvatarFromUrlJob.perform_later(contact, avatar_url)
  end

  def zaphub_event_type
    params[:event].presence ||
      params[:type].presence ||
      raw_zaphub_payload[:event].presence ||
      raw_zaphub_payload[:type].presence ||
      params.dig(:callback, :event)
  end

  def zaphub_payload
    @zaphub_payload ||= begin
      payload = raw_zaphub_payload
      3.times do
        nested = payload[:data]
        break unless nested.is_a?(Hash) || nested.respond_to?(:permit!)

        nested = nested.to_unsafe_h if nested.respond_to?(:permit!)
        payload = nested.with_indifferent_access
      end
      payload
    end
  end

  def raw_zaphub_payload
    @raw_zaphub_payload ||= begin
      raw_payload = params[:data] || params[:payload] || params.dig(:callback, :payload) || {}
      raw_payload = raw_payload.to_unsafe_h if raw_payload.respond_to?(:permit!)
      raw_payload.with_indifferent_access
    end
  end

  def raw_request_body
    @raw_request_body ||= begin
      body = request.body.read
      request.body.rewind
      body.to_s
    end
  end

  def zaphub_webhook_signature_secret
    @zaphub_webhook_signature_secret ||= begin
      env_secret = ENV['WEBHOOK_SIGNATURE_SECRET'].presence || ENV['ZAPHUB_WEBHOOK_SIGNATURE_SECRET'].presence
      channel_secret = @channel&.api_key.presence
      env_secret.presence || channel_secret.presence
    end
  end

  def message_sent_by_us?(message_data, event_type = nil)
    normalized_event = event_type.to_s
    return true if %w[message.sent message.outgoing].include?(normalized_event)
    return false if %w[message.received message.incoming].include?(normalized_event)

    direction = message_data[:direction]
    if direction.present?
      downcased = direction.to_s.downcase
      return true if downcased == 'outgoing'
      return false if downcased == 'incoming'
    end

    flag = message_data[:fromMe]
    flag = message_data[:from_me] if flag.nil?
    flag = message_data[:is_from_me] if flag.nil?
    flag = message_data[:own] if flag.nil?
    flag = message_data[:outgoing] if flag.nil?
    flag = message_data[:sent_by_me] if flag.nil?
    flag = message_data[:from_self] if flag.nil?
    flag = message_data.dig(:key, :fromMe) if flag.nil?
    flag = message_data.dig(:metadata, :fromMe) if flag.nil?

    ActiveModel::Type::Boolean.new.cast(flag)
  end

  def message_sender_identifier(message_data, sent_by_us = false)
    identifiers = []
    if sent_by_us
      identifiers << message_data[:to]
      identifiers << message_data[:recipient]
    end

    identifiers << message_data[:from]
    identifiers << message_data[:participant]
    identifiers << message_data[:author]
    identifiers << message_data[:chatId] if group_chat?(message_data)
    identifiers << message_data[:chatId]
    identifiers << message_data[:chat_id]
    identifiers << message_data[:remoteJid]

    identifiers = identifiers.compact_blank.map { |id| normalize_jid(id) }
    identifiers.first || "zaphub-unknown-#{SecureRandom.uuid}"
  end

  def message_chat_identifier(message_data, sent_by_us, fallback_identifier = nil)
    raw = message_data[:chatId] ||
          message_data[:chat_id] ||
          fallback_identifier ||
          message_sender_identifier(message_data, sent_by_us)

    normalize_jid(raw)
  end

  def group_chat?(message_data)
    return false if message_data.blank?

    ActiveModel::Type::Boolean.new.cast(message_data[:isGroup]) ||
      ActiveModel::Type::Boolean.new.cast(message_data[:group]) ||
      message_data[:groupId].present? ||
      message_data[:chatId].to_s.include?('-')
  end

  def normalize_jid(value)
    return value if value.blank?

    jid = value.to_s
    local, domain = jid.split('@', 2)
    return jid if local.blank?

    local = local.split(':').first
    return jid if local.blank?

    normalized_domain = if domain&.include?('g.us')
                          'g.us'
                        else
                          's.whatsapp.net'
                        end

    "#{local}@#{normalized_domain}"
  end

  def log_attachment_urls(message)
    return unless request

    uri = URI.parse(request.base_url)
    ActiveStorage::Current.url_options = {
      host: uri.host,
      port: uri.port,
      protocol: uri.scheme
    }

    attachment_urls = message.attachments.map do |attachment|
      {
        id: attachment.id,
        data_url: attachment.push_event_data[:data_url],
        thumb_url: attachment.push_event_data[:thumb_url]
      }
    end

    Rails.logger.info "[Zaphub] message #{message.id} attachment urls: #{attachment_urls.inspect}"
  rescue StandardError => e
    Rails.logger.warn "[Zaphub] failed to log attachment urls: #{e.message}"
  end
end
