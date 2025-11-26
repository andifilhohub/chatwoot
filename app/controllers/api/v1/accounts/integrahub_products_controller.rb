class Api::V1::Accounts::IntegrahubProductsController < Api::V1::Accounts::BaseController
  require 'rest-client'

  # GET /api/v1/accounts/:account_id/integrahub_products
  # Proxies to IntegraHub GET /v1/products?cnpj=...&q=...&limit=...&page=...
  def index
    cnpj = Current.account&.cnpj

    if cnpj.blank?
      render json: { items: [], pagination: { page: 1, limit: 0, count: 0 } } and return
    end

  base_url = ENV['INTEGRAHUB_URL'] || Rails.application.credentials.dig(:integrahub, :url)
    api_key = ENV['INTEGRAHUB_API_KEY'] || Rails.application.credentials.dig(:integrahub, :api_key)

    unless base_url.present?
      render json: { error: 'IntegraHub URL not configured' }, status: :bad_gateway and return
    end

    query = {
      cnpj: cnpj,
      q: params[:q].presence,
      limit: params[:limit].presence,
      page: params[:page].presence
    }.compact

  # Normalize configured base to avoid double "/api" (e.g. if INTEGRAHUB_URL ends with "/api")
  # Keep the original string in logs, but use a normalized base for building URLs.
  normalized_base = base_url.to_s.sub(%r{/api/?\z}i, '')
  base = normalized_base.end_with?('/') ? normalized_base : "#{normalized_base}/"
  url = URI.join(base, 'v1/products').to_s

    # Build full URL with querystring to avoid passing params in headers
    final_url = query.any? ? "#{url}?#{URI.encode_www_form(query)}" : url

    headers = { accept: :json }
    headers[:authorization] = "Bearer #{api_key}" if api_key.present?
    headers['X-Api-Key'] = api_key if api_key.present? && !headers[:authorization]

    tried_urls = [final_url]

    begin
      # add sensible timeouts so long hangs return clearly
  response = RestClient::Request.execute(method: :get, url: final_url, headers: headers, open_timeout: 5, read_timeout: 10)
  # Log successful upstream response body to assist debugging (shows actual IntegraHub payload)
  Rails.logger.info("IntegraHub upstream success: url=#{final_url} body=#{response.body}")
  parsed = JSON.parse(response.body)
  render json: parsed and return
    rescue RestClient::ExceptionWithResponse => e
      # Log upstream status, URL and headers for debugging
      Rails.logger.error("IntegraHub proxy error: status=#{e.http_code} url=#{final_url} headers=#{headers.inspect}")
      # Also log upstream response body when available (helps diagnose 4xx/5xx reasons)
      begin
        Rails.logger.error("IntegraHub upstream body: #{e.response.body}") if e.response && e.response.body
      rescue StandardError => _log_err
        Rails.logger.error("IntegraHub upstream body: <unreadable>")
      end
      if e.http_code == 404
        # Try an alternate URL variant: strip a leading /api from the configured base (common local mismatch)
        if base.match(%r{/api/?$}) || base.include?('/api/')
          alt_base = base.sub(%r{/api/?}, '/')
          alt_url = URI.join(alt_base, 'v1/products').to_s
          alt_final_url = query.any? ? "#{alt_url}?#{URI.encode_www_form(query)}" : alt_url
          tried_urls << alt_final_url
          Rails.logger.info("IntegraHub proxy: initial URL returned 404, trying alternate URL #{alt_final_url}")
          begin
            response2 = RestClient::Request.execute(method: :get, url: alt_final_url, headers: headers, open_timeout: 5, read_timeout: 10)
            # Also log successful alternate upstream response
            Rails.logger.info("IntegraHub upstream success (alternate): url=#{alt_final_url} body=#{response2.body}")
            parsed2 = JSON.parse(response2.body)
            render json: parsed2 and return
          rescue RestClient::ExceptionWithResponse => e2
            Rails.logger.error("IntegraHub proxy alternate error: status=#{e2.http_code} url=#{alt_final_url}")
            begin
              Rails.logger.error("IntegraHub alternate upstream body: #{e2.response.body}") if e2.response && e2.response.body
            rescue StandardError
              Rails.logger.error("IntegraHub alternate upstream body: <unreadable>")
            end
            body2 = begin
              JSON.parse(e2.response.body) rescue { error: e2.response.body }
            end
            render json: body2, status: e2.http_code || :bad_gateway and return
          rescue RestClient::Exceptions::Timeout, Errno::ETIMEDOUT => e2
            Rails.logger.error("IntegraHub timeout when contacting alternate URL #{alt_url}: #{e2.class} #{e2.message}")
            render json: { error: 'IntegraHub request timed out when trying alternate URL' }, status: :bad_gateway and return
          rescue StandardError => e2
            Rails.logger.error("IntegraHub proxy unexpected error for alternate URL #{alt_url}: #{e2.class} #{e2.message}\n#{e2.backtrace&.join("\n")}")
            render json: { error: e2.message }, status: :bad_gateway and return
          end
        end
      end

      # return upstream error body if no alternate helped
      body = begin
        JSON.parse(e.response.body) rescue { error: e.response.body }
      end
      render json: body, status: e.http_code || :bad_gateway
    rescue RestClient::Exceptions::Timeout, Errno::ETIMEDOUT => e
      Rails.logger.error("IntegraHub timeout when contacting #{final_url}: #{e.class} #{e.message}")
      render json: { error: 'IntegraHub request timed out' }, status: :bad_gateway
    rescue StandardError => e
      Rails.logger.error("IntegraHub proxy unexpected error for #{final_url} (tried: #{tried_urls.join(', ')}): #{e.class} #{e.message}\n#{e.backtrace&.join("\n")}")
      render json: { error: e.message }, status: :bad_gateway
    end
  end
end

Api::V1::Accounts::IntegrahubProductsController.prepend_mod_with('Api::V1::Accounts::IntegrahubProductsController')
