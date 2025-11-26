module Zaphub
  class SessionService
    attr_reader :channel

    def initialize(channel)
      @channel = channel
    end

    def create_session
      response = make_request(
        :post,
        '/api/v1/sessions',
        {
          label: "Chatwoot - #{channel.inbox&.name || 'Inbox'}",
          webhook_url: webhook_callback_url
        }
      )

      response['data'] || response
    end

    def fetch_qr_code
      return unless channel.session_id

      # ZapHub API retorna QR code em base64 com format=data_url
      response = make_request(:get, "/api/v1/sessions/#{channel.session_id}/qr?format=data_url")
      response['data'] || response
    end

    def check_status
      return unless channel.session_id

      response = make_request(:get, "/api/v1/sessions/#{channel.session_id}/status")
      response['data'] || response
    end

    def update_webhook
      return unless channel.session_id

      response = make_request(
        :patch,
        "/api/v1/sessions/#{channel.session_id}",
        {
          webhook_url: webhook_callback_url
        }
      )

      response['data'] || response
    end

    def send_message(params)
      return unless channel.session_id

      response = make_request(
        :post,
        "/api/v1/sessions/#{channel.session_id}/messages",
        params
      )
      
      response['data'] || response
    end

    def send_event(event_name, data = {})
      return unless channel.session_id

      payload = {
        event: event_name,
        data: data || {}
      }

      response = make_request(
        :post,
        "/api/v1/sessions/#{channel.session_id}/events",
        payload
      )

      response['data'] || response
    end

    def edit_message(message_id, params)
      return unless channel.session_id

      response = make_request(
        :patch,
        "/api/v1/sessions/#{channel.session_id}/messages/#{message_id}",
        params
      )
      
      response['data'] || response
    end

    def delete_message(message_id)
      return unless channel.session_id

      response = make_request(
        :delete,
        "/api/v1/sessions/#{channel.session_id}/messages/#{message_id}",
        nil
      )
      
      response['data'] || response
    end

    private

    def make_request(method, path, body = nil)
      # Normalize base_url to avoid double "/api" or missing slash issues
      normalized_base = channel.base_url.to_s.sub(%r{/api/?\z}i, '')
      base = normalized_base.end_with?('/') ? normalized_base : "#{normalized_base}/"
      # Ensure path does not add a doubled leading slash when using URI.join
      path_fragment = path.to_s.sub(%r{\A/}, '')
      url = URI.join(base, path_fragment).to_s

      headers = {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{channel.api_key}"
      }

      Rails.logger.info("ZapHub request: method=#{method} url=#{url} headers=#{headers.except('Authorization').inspect} body=#{body.inspect}")

      response = case method
                 when :get
                   HTTParty.get(url, headers: headers, timeout: 10)
                 when :post
                   HTTParty.post(url, headers: headers, body: body.to_json, timeout: 10)
                 when :patch
                   HTTParty.patch(url, headers: headers, body: body.to_json, timeout: 10)
                 when :delete
                   HTTParty.delete(url, headers: headers, timeout: 10)
                 end

      Rails.logger.info("ZapHub response: code=#{response&.code} body=#{response&.body.to_s.truncate(1000)}")

      handle_response(response)
    end

    def handle_response(response)
      case response.code
      when 200, 201, 204
        # 204 No Content doesn't have a body
        return {} if response.code == 204
        JSON.parse(response.body) rescue {}
      when 400, 422
        error_message = JSON.parse(response.body)['error'] rescue 'Bad Request'
        raise "ZapHub API Error: #{error_message}"
      when 401
        raise 'ZapHub API Error: Unauthorized - Check your API key'
      when 404
        raise 'ZapHub API Error: Session not found'
      when 500, 502, 503
        raise 'ZapHub API Error: Server error'
      else
        raise "ZapHub API Error: Unexpected response code #{response.code}"
      end
    rescue JSON::ParserError
      raise 'ZapHub API Error: Invalid response format'
    end

    def webhook_callback_url
      Rails.application.routes.url_helpers.zaphub_callback_url(
        channel_id: channel.id,
        host: ENV.fetch('FRONTEND_URL', nil)
      )
    end
  end
end
