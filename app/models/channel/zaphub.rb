# == Schema Information
#
# Table name: channel_zaphub
#
#  id                    :bigint           not null, primary key
#  additional_attributes :jsonb
#  api_key               :string
#  base_url              :string
#  connected_at          :datetime
#  qr_code_data          :text
#  status                :string           default("pending")
#  webhook_url           :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :integer          not null
#  session_id            :string
#
# Indexes
#
#  index_channel_zaphub_on_account_id  (account_id)
#  index_channel_zaphub_on_session_id  (session_id) UNIQUE
#

class Channel::Zaphub < ApplicationRecord
  include Channelable

  self.table_name = 'channel_zaphub'
  QR_FETCH_MAX_ATTEMPTS = 3
  QR_FETCH_RETRY_DELAY = 3.seconds
  RETRYABLE_QR_ERRORS = ['session not found', 'qr code not available'].freeze

  EDITABLE_ATTRS = [:api_key, :base_url, :webhook_url, { additional_attributes: {} }].freeze

  validates :status, inclusion: { in: %w[pending qr_generated connected disconnected error] }
  before_destroy :disconnect_session

  # API credentials from environment variables
  def api_key
    self[:api_key].presence || ENV.fetch('ZAPHUB_API_KEY', nil)
  end

  def base_url
    self[:base_url].presence ||
      ENV['ZAPHUB_API_URL'].presence ||
      ENV['ZAPHUB_BASE_URL'].presence ||
      'https://api.zaphub.com.br'
  end

  def name
    'ZapHub WhatsApp'
  end

  def messaging_service_sid
    session_id
  end

  def connected?
    status == 'connected'
  end

  def create_session
    service = Zaphub::SessionService.new(self)
    response = service.create_session
    update!(
      session_id: response['id'],
      status: 'qr_generated'
    )
    
    # Atualizar webhook após criar sessão (workaround para bug do ZapHub)
    begin
      service.update_webhook
    rescue StandardError => e
      Rails.logger.warn "Failed to update webhook (non-critical): #{e.message}"
    end
    
    response
  rescue StandardError => e
    Rails.logger.error "ZapHub session creation failed: #{e.message}"
    update!(status: 'error')
    raise
  end

  def fetch_qr_code
    return nil unless session_id

    attempts = 0

    begin
      response = Zaphub::SessionService.new(self).fetch_qr_code
      qr_data = response['qr_code'] || response['qr']
      update!(qr_code_data: qr_data) if qr_data
      response
    rescue StandardError => e
      attempts += 1
      if attempts < QR_FETCH_MAX_ATTEMPTS && retryable_qr_error?(e.message)
        sleep(QR_FETCH_RETRY_DELAY)
        retry
      end

      Rails.logger.error "ZapHub QR fetch failed: #{e.message}"
      nil
    end
  end

  def check_status
    return unless session_id

    response = Zaphub::SessionService.new(self).check_status
    # ZapHub retorna status como 'connected' quando autenticado
    api_status = response['status']
    
    # Map ZapHub status to internal status
    new_status = case api_status
                 when 'connected'
                   'connected'
                 when 'initializing', 'qr_generated'
                   'qr_generated'
                 when 'disconnected'
                   'disconnected'
                 else
                   'pending'
                 end
    
    if new_status == 'connected' && status != 'connected'
      update!(status: new_status, connected_at: Time.current)
    else
      update!(status: new_status)
    end
    
    response
  rescue StandardError => e
    Rails.logger.error "ZapHub status check failed: #{e.message}"
    update!(status: 'error')
    nil
  end

  def retryable_qr_error?(message)
    downcased = message.to_s.downcase
    RETRYABLE_QR_ERRORS.any? { |error| downcased.include?(error) }
  end

  private

  def disconnect_session
    return unless session_id.present?

    Zaphub::SessionService.new(self).destroy_session
  rescue StandardError => e
    Rails.logger.warn "ZapHub disconnect failed for channel #{id}: #{e.message}"
  end
end
