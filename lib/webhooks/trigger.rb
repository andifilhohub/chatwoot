class Webhooks::Trigger
  SUPPORTED_ERROR_HANDLE_EVENTS = %w[message_created message_updated].freeze
  DEFAULT_TIMEOUT_SECONDS = 20
  DEFAULT_TIMEOUT_RETRIES = 2

  def initialize(url, payload, webhook_type)
    @url = url
    @payload = payload
    @webhook_type = webhook_type
  end

  def self.execute(url, payload, webhook_type)
    new(url, payload, webhook_type).execute
  end

  def execute
    perform_request
  rescue StandardError => e
    handle_error(e)
    Rails.logger.warn "Exception: Invalid webhook URL #{@url} : #{e.message}"
  end

  private

  def perform_request
    attempts = 0

    begin
      attempts += 1
      RestClient::Request.execute(
        method: :post,
        url: @url,
        payload: @payload.to_json,
        headers: { content_type: :json, accept: :json },
        open_timeout: webhook_timeout_seconds,
        read_timeout: webhook_timeout_seconds
      )
    rescue RestClient::Exceptions::OpenTimeout,
           RestClient::Exceptions::ReadTimeout,
           Net::OpenTimeout,
           Net::ReadTimeout => e
      raise if attempts > webhook_timeout_retries

      Rails.logger.warn("Webhook timeout for #{@url} (attempt #{attempts}/#{webhook_timeout_retries + 1}): #{e.message}")
      retry
    end
  end

  def handle_error(error)
    return unless should_handle_error?
    return unless message

    update_message_status(error)
  end

  def should_handle_error?
    @webhook_type == :api_inbox_webhook && SUPPORTED_ERROR_HANDLE_EVENTS.include?(@payload[:event])
  end

  def update_message_status(error)
    Messages::StatusUpdateService.new(message, 'failed', error.message).perform
  end

  def message
    return if message_id.blank?

    @message ||= Message.find_by(id: message_id)
  end

  def message_id
    @payload[:id]
  end

  def webhook_timeout_seconds
    value = ENV.fetch('API_INBOX_WEBHOOK_TIMEOUT', DEFAULT_TIMEOUT_SECONDS).to_i
    value.positive? ? value : DEFAULT_TIMEOUT_SECONDS
  end

  def webhook_timeout_retries
    value = ENV.fetch('API_INBOX_WEBHOOK_TIMEOUT_RETRIES', DEFAULT_TIMEOUT_RETRIES).to_i
    value.positive? ? value : 0
  end
end
