class Api::V1::Accounts::Channels::ZaphubChannelsController < Api::V1::Accounts::BaseController
  before_action :fetch_inbox, only: [:create_session, :qr_code, :status, :disconnect]

  def create_session
    authorize @inbox, :update?
    
    Rails.logger.info "🚀 Creating ZapHub session for inbox #{@inbox.id}"
    
    response = @inbox.channel.create_session
    
    Rails.logger.info "✅ ZapHub session created: session_id=#{@inbox.channel.session_id}, status=#{@inbox.channel.status}"
    
    render json: {
      success: true,
      data: {
        session_id: @inbox.channel.session_id,
        status: @inbox.channel.status
      }
    }, status: :ok
  rescue StandardError => e
    Rails.logger.error "❌ ZapHub session creation failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { 
      error: e.message,
      details: "Failed to create session in ZapHub API. Check if ZAPHUB_API_URL and ZAPHUB_API_KEY are configured."
    }, status: :unprocessable_entity
  end

  def qr_code
    authorize @inbox, :show?
    
    response = @inbox.channel.fetch_qr_code
    
    # Buscar qr_code tanto com underscore quanto sem
    qr_data = response&.dig('qr_code') || response&.dig('qr') || @inbox.channel.qr_code_data
    
    if qr_data
      render json: {
        success: true,
        data: {
          qr: qr_data,
          qr_code: qr_data,  # Retornar ambos para compatibilidade
          status: @inbox.channel.status
        }
      }, status: :ok
    else
      render json: { 
        error: 'QR code not available',
        details: 'Session may still be initializing. Please wait a few seconds.'
      }, status: :not_found
    end
  rescue StandardError => e
    Rails.logger.error "ZapHub QR Code Error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def status
    authorize @inbox, :show?
    
    response = @inbox.channel.check_status
    
    Rails.logger.info "ZapHub Status Response: #{response.inspect}"
    
    render json: {
      success: true,
      data: {
        status: response&.dig('db_status') || response&.dig('status') || @inbox.channel.status,
        db_status: response&.dig('db_status'),
        runtime_status: response&.dig('runtime_status'),
        is_connected: response&.dig('is_connected'),
        connected_at: response&.dig('connected_at') || @inbox.channel.connected_at,
        session_id: @inbox.channel.session_id
      }
    }, status: :ok
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def disconnect
    authorize @inbox, :update?
    
    begin
      Zaphub::SessionService.new(@inbox.channel).destroy_session
    rescue StandardError => e
      Rails.logger.warn "ZapHub API disconnect failed: #{e.message}"
    end

    @inbox.channel.update!(status: 'disconnected')
    
    render json: {
      success: true,
      message: 'Channel disconnected successfully'
    }, status: :ok
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:id])
  end
end
