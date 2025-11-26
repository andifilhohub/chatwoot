class Api::V1::Accounts::Conversations::MessagesController < Api::V1::Accounts::Conversations::BaseController
  ZAPHUB_STATUS_EVENTS = {
    'read' => 'message.read',
    'delivered' => 'message.delivered'
  }.freeze

  before_action :ensure_api_inbox, only: :update

  def index
    @messages = message_finder.perform
  end

  def create
    user = Current.user || @resource
    mb = Messages::MessageBuilder.new(user, @conversation, params)
    @message = mb.perform
  rescue StandardError => e
    render_could_not_create_error(e.message)
  end

  def update
    # Support both status updates and content edits
    if permitted_params[:content].present?
      # Edit message content
      edit_message_content
    else
      # Update message status
      status = permitted_params[:status]
      service = Messages::StatusUpdateService.new(message, status, permitted_params[:external_error])
      updated = service.perform
      send_zaphub_status_event(status) if updated
    end
    @message = message
  end

  def destroy
    previous_content = message.content
    # If Zaphub channel, delete via Zaphub API first
    if message.inbox.channel_type == 'Channel::Zaphub' && message.outgoing? && message.source_id.present?
      begin
        Zaphub::DeleteMessageService.new(message: message).perform
      rescue StandardError => e
        Rails.logger.error "Failed to delete message via Zaphub: #{e.message}"
        # Continue with local deletion even if Zaphub fails
      end
    end

    ActiveRecord::Base.transaction do
      message.update!(content: I18n.t('conversations.messages.deleted'), content_type: :text, content_attributes: { deleted: true })
      message.attachments.destroy_all
    end

    send_zaphub_delete_event(previous_content)
  end

  def retry
    return if message.blank?

    service = Messages::StatusUpdateService.new(message, 'sent')
    service.perform
    message.update!(content_attributes: {})
    ::SendReplyJob.perform_later(message.id)
  rescue StandardError => e
    render_could_not_create_error(e.message)
  end

  def translate
    return head :ok if already_translated_content_available?

    translated_content = Integrations::GoogleTranslate::ProcessorService.new(
      message: message,
      target_language: permitted_params[:target_language]
    ).perform

    if translated_content.present?
      translations = {}
      translations[permitted_params[:target_language]] = translated_content
      translations = message.translations.merge!(translations) if message.translations.present?
      message.update!(translations: translations)
    end

    render json: { content: translated_content }
  end

  private

  def message
    @message ||= @conversation.messages.find(permitted_params[:id])
  end

  def message_finder
    @message_finder ||= MessageFinder.new(@conversation, params)
  end

  def permitted_params
    params.permit(:id, :target_language, :status, :external_error, :content)
  end

  def edit_message_content
    new_content = permitted_params[:content]
    return if new_content.blank?

    previous_content = message.content

    # If Zaphub channel, try to edit via Zaphub API (but continue even if it fails)
    if message.inbox.channel_type == 'Channel::Zaphub' && message.outgoing? && message.source_id.present?
      begin
        Zaphub::EditMessageService.new(message: message, new_content: new_content).perform
      rescue StandardError => e
        Rails.logger.error "Failed to edit message via Zaphub, continuing with local edit: #{e.message}"
        # Continue with local edit even if Zaphub fails
      end
    end

    # Update local message content (always happens, even if Zaphub edit fails)
    message.update!(content: new_content)

    send_zaphub_edit_event(previous_content, new_content)
  end

  def send_zaphub_edit_event(previous_content, new_content)
    return unless message.inbox.channel_type == 'Channel::Zaphub'

    event_data = {}
    event_data[:content] = { text: new_content } if new_content.present?
    event_data[:previousContent] = { text: previous_content } if previous_content.present?

    Zaphub::EventService.new(message: message, event: 'message.edited', data: event_data).perform
  end

  def send_zaphub_delete_event(previous_content)
    return unless message.inbox.channel_type == 'Channel::Zaphub'

    event_data = {}
    event_data[:previousContent] = { text: previous_content } if previous_content.present?

    Zaphub::EventService.new(message: message, event: 'message.deleted', data: event_data).perform
  end

  def send_zaphub_status_event(status)
    return unless message.inbox.channel_type == 'Channel::Zaphub'
    return if status.blank?

    event = ZAPHUB_STATUS_EVENTS[status.to_s]
    return unless event

    Zaphub::EventService.new(message: message, event: event, data: { status: status.to_s }).perform
  end

  def already_translated_content_available?
    message.translations.present? && message.translations[permitted_params[:target_language]].present?
  end

  # API inbox check
  def ensure_api_inbox
    # Allow content edits for Zaphub channels
    if params[:content].present? && @conversation.inbox.channel_type == 'Channel::Zaphub'
      return
    end
    
    # Only API inboxes can update message status
    render json: { error: 'Message status update is only allowed for API inboxes' }, status: :forbidden unless @conversation.inbox.api?
  end
end
