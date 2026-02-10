class Api::V1::Accounts::IntegrahubSalesController < Api::V1::Accounts::BaseController
  require 'rest-client'

  # POST /api/v1/accounts/:account_id/integrahub_sales
  # Proxies to IntegraHub POST /v1/sales
  def create
    sale_payload = params.require(:payload)

    base_url = ENV['INTEGRAHUB_URL'] || Rails.application.credentials.dig(:integrahub, :url)
    api_key = ENV['INTEGRAHUB_API_KEY'] || Rails.application.credentials.dig(:integrahub, :api_key)

    unless base_url.present?
      render json: { error: 'IntegraHub URL not configured' }, status: :bad_gateway and return
    end

    normalized_base = base_url.to_s.sub(%r{/api/?\z}i, '')
    base = normalized_base.end_with?('/') ? normalized_base : "#{normalized_base}/"
    url = URI.join(base, 'v1/sales').to_s

    idempotency_key = sale_payload[:codigoVendaOnLine].presence || sale_payload['codigoVendaOnLine'].presence
    idempotency_key = "sale-#{idempotency_key}" if idempotency_key.present?

    headers = { content_type: :json, accept: :json }
    headers[:authorization] = "Bearer #{api_key}" if api_key.present?
    headers['X-Api-Key'] = api_key if api_key.present? && !headers[:authorization]
    headers['Idempotency-Key'] = idempotency_key if idempotency_key.present?

    response = RestClient::Request.execute(
      method: :post,
      url: url,
      payload: sale_payload.to_json,
      headers: headers,
      open_timeout: 5,
      read_timeout: 10
    )

    parsed = JSON.parse(response.body) rescue { status: 'sent', upstream_status: response.code }
    render json: parsed, status: :ok
  rescue ActionController::ParameterMissing => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue RestClient::ExceptionWithResponse => e
    Rails.logger.error("IntegraHub sales proxy error: status=#{e.http_code} url=#{url}")
    begin
      Rails.logger.error("IntegraHub sales upstream body: #{e.response.body}") if e.response && e.response.body
    rescue StandardError
      Rails.logger.error("IntegraHub sales upstream body: <unreadable>")
    end
    body = begin
      JSON.parse(e.response.body) rescue { error: e.response.body }
    end
    render json: body, status: e.http_code || :bad_gateway
  rescue RestClient::Exceptions::Timeout, Errno::ETIMEDOUT => e
    Rails.logger.error("IntegraHub sales timeout when contacting #{url}: #{e.class} #{e.message}")
    render json: { error: 'IntegraHub request timed out' }, status: :bad_gateway
  rescue StandardError => e
    Rails.logger.error("IntegraHub sales proxy unexpected error for #{url}: #{e.class} #{e.message}\n#{e.backtrace&.join("\n")}")
    render json: { error: e.message }, status: :bad_gateway
  end
end

Api::V1::Accounts::IntegrahubSalesController.prepend_mod_with('Api::V1::Accounts::IntegrahubSalesController')
