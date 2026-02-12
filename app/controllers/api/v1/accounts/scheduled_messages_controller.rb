class Api::V1::Accounts::ScheduledMessagesController < Api::V1::Accounts::BaseController
  RESULTS_PER_PAGE = 25

  before_action :set_current_page, only: :index
  before_action :find_message, only: [:update, :destroy]

  def index
    @scheduled_messages = filtered_scope
                          .includes(:scheduled_message_job,
                                    :inbox,
                                    :sender,
                                    { conversation: :contact },
                                    { attachments: :blob })
                          .reorder('messages.created_at DESC')
                          .page(@current_page)
                          .per(per_page)
  end

  def update
    return render_error({ message: I18n.t('scheduled_messages.errors.not_editable') }, :unprocessable_entity) unless schedulable_for_management?

    assign_schedule_attributes!
    ActiveRecord::Base.transaction do
      @message.save!
      reschedule_delivery!
    end

    render 'api/v1/accounts/conversations/messages/create', status: :ok
  end

  def destroy
    return render_error({ message: I18n.t('scheduled_messages.errors.not_cancellable') }, :unprocessable_entity) unless schedulable_for_management?

    ActiveRecord::Base.transaction do
      cancel_schedule!(@schedule_record)
      mark_message_cancelled!
    end

    render 'api/v1/accounts/conversations/messages/create', status: :ok
  end

  private

  def per_page
    value = params[:per_page].presence || RESULTS_PER_PAGE
    value.to_i.positive? ? value.to_i : RESULTS_PER_PAGE
  end

  def set_current_page
    page = params[:page].presence || 1
    @current_page = page.to_i.positive? ? page.to_i : 1
  end

  def filtered_scope
    scope = Current.account.messages
                   .where(status: [Message.statuses[:scheduled], Message.statuses[:sent]])
                   .where.not(scheduled_at: nil)
                   .left_outer_joins(:scheduled_message_job)

    if params[:status].present?
      scope = scope.where(
        'scheduled_message_jobs.status = :status OR (scheduled_message_jobs.id IS NULL AND :status = :fallback_status)',
        status: params[:status],
        fallback_status: ScheduledMessageJob.statuses[:scheduled]
      )
    end

    scope = scope.where(inbox_id: params[:inbox_id]) if params[:inbox_id].present?
    scope = scope.where(sender_id: params[:agent_id]) if params[:agent_id].present?
    scope = scope.where(conversation_id: params[:conversation_id]) if params[:conversation_id].present?
    scope = filter_by_contact(scope)
    scope = filter_by_search(scope)
    scope = filter_by_date_range(scope, 'messages.scheduled_at', params[:scheduled_from], params[:scheduled_to])
    filter_message_date_range(scope)
  end

  def filter_by_contact(scope)
    return scope if params[:contact_id].blank?

    scope.left_outer_joins(:conversation).where(conversations: { contact_id: params[:contact_id] })
  end

  def filter_by_search(scope)
    return scope if params[:q].blank?

    scope.where('messages.content ILIKE ?', "%#{params[:q]}%")
  end

  def filter_message_date_range(scope)
    filter_by_date_range(scope, 'messages.created_at', params[:created_from], params[:created_to])
  end

  def filter_by_date_range(scope, column, from_value, to_value)
    return scope unless from_value.present? || to_value.present?

    from_time = parse_datetime(from_value)
    to_time = parse_datetime(to_value)

    scope = scope.where("#{column} >= ?", from_time) if from_time
    scope = scope.where("#{column} <= ?", to_time) if to_time
    scope
  end

  def parse_datetime(value)
    return if value.blank?

    Time.zone.parse(value.to_s)
  rescue ArgumentError
    nil
  end

  def find_message
    @message = Current.account.messages.find(params[:id])
    @schedule_record = @message.scheduled_message_job
  end

  def schedulable_for_management?
    return false if @message.sent?
    return false if @message.scheduled_at.blank?

    @schedule_record&.scheduled?
  end

  def assign_schedule_attributes!
    schedule_params = permitted_schedule_params
    @message.assign_attributes(message_update_params)

    return if schedule_params[:scheduled_at].blank?

    @message.scheduled_at = schedule_params[:scheduled_at]
    info = @message.schedule_info.is_a?(Hash) ? @message.schedule_info.deep_dup : {}
    info['scheduled_at'] = @message.scheduled_at.iso8601
    info['scheduled_timezone'] = schedule_params[:scheduled_timezone] if schedule_params[:scheduled_timezone].present?
    info['scheduled_by_id'] = Current.user&.id if Current.user.present?
    info['scheduled_by_name'] = Current.user.name if Current.user.respond_to?(:name)
    info['scheduled_updated_at'] = Time.current.iso8601
    @message.schedule_info = info
  end

  def reschedule_delivery!
    info = @message.schedule_info.is_a?(Hash) ? @message.schedule_info : {}
    Messages::ScheduledDeliveryService.new(
      message: @message,
      scheduled_at: @message.scheduled_at,
      timezone: info['scheduled_timezone'],
      metadata: info
    ).schedule!
  end

  def cancel_schedule!(schedule_record)
    metadata = schedule_record&.metadata || (@message.schedule_info || {})
    timezone = schedule_record&.timezone || metadata['scheduled_timezone']

    Messages::ScheduledDeliveryService.new(
      message: @message,
      scheduled_at: @message.scheduled_at,
      timezone: timezone,
      metadata: metadata
    ).cancel!(reason: I18n.t('scheduled_messages.status.cancelled_by_agent'))
  end

  def mark_message_cancelled!
    info = @message.schedule_info.is_a?(Hash) ? @message.schedule_info.deep_dup : {}
    info['cancelled_at'] = Time.current.iso8601
    info['cancelled_by_id'] = Current.user&.id if Current.user.present?
    info['cancelled_by_name'] = Current.user.name if Current.user.respond_to?(:name)

    @message.update!(
      status: Message.statuses[:failed],
      schedule_info: info,
      content_attributes: (@message.content_attributes || {}).merge(deleted: true)
    )
  end

  def message_update_params
    permitted_params.slice(:content).compact_blank
  end

  def permitted_schedule_params
    {
      scheduled_at: parse_datetime(permitted_params[:scheduled_at]),
      scheduled_timezone: permitted_params[:scheduled_timezone]
    }.compact
  end

  def permitted_params
    params.require(:scheduled_message).permit(:content, :scheduled_at, :scheduled_timezone)
  end
end
