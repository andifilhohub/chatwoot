require 'net/http'
require 'openssl'
require 'base64'
require 'digest'

module Zaphub
  class MediaAttachmentService
    MEDIA_CONFIG = {
      'image' => { key: :image, file_type: 'image', extension: '.jpg', default_mime: 'image/jpeg' },
      'video' => { key: :video, file_type: 'video', extension: '.mp4', default_mime: 'video/mp4' },
      'audio' => { key: :audio, file_type: 'audio', extension: '.ogg', default_mime: 'audio/ogg' },
      'document' => { key: :document, file_type: 'file', extension: '.bin', default_mime: 'application/octet-stream' }
    }.freeze

    def initialize(message_data:, type:, file_name: nil, request: nil)
      @message_data = message_data
      @type = type
      @file_name = file_name
      @request = request
      @raw_media = message_data[:raw_media] || message_data[:rawMedia] || {}
      @skip_sha_validation = false
    end

    def call
      media_url = url
      return nil if media_url.blank?

      Rails.logger.info "[Zaphub] ===== MEDIA DOWNLOAD INFO ====="
      Rails.logger.info "[Zaphub] Using full media URL from raw_media"
      Rails.logger.info "[Zaphub] Final chosen URL: #{media_url}"
      Rails.logger.info "[Zaphub] mediaKey: #{media_key_base64}"
      Rails.logger.info "[Zaphub] fileLength esperado: #{raw_media[:fileLength]}"
      Rails.logger.info "[Zaphub] =================================="

      body, response = fetch_raw_media_bytes(media_url)
      return nil unless body

      Rails.logger.info "[Zaphub] Downloaded #{body.bytesize} bytes"

      # Normaliza corpo (remove cabeçalho se tiver) usando fileLength + fileEncSha256
      body = normalize_cipher_body(body)

      # Garante integridade do ciphertext (se fileEncSha256 existir)
      validate_sha256!(body)

      # Decripta se tiver mediaKey
      if media_key_base64.present?
        Rails.logger.info "[Zaphub] Starting decrypt..."
        body = decrypt(body)
        Rails.logger.info "[Zaphub] Decrypt success (#{body.bytesize} bytes)"
      else
        Rails.logger.info "[Zaphub] No mediaKey provided — using raw data"
      end

      tempfile = Tempfile.new(['zaphub', config[:extension]])
      tempfile.binmode
      tempfile.write(body)
      tempfile.rewind

      filename = final_file_name(tempfile, media_url)
      content_type_value = content_type(response)

      Rails.logger.info "[Zaphub] Created file: #{filename} | size=#{body.bytesize} | type=#{content_type_value}"

      {
        io: tempfile,
        filename: filename,
        content_type: content_type_value,
        file_type: config[:file_type]
      }
    rescue => e
      Rails.logger.error "Failed to download ZapHub attachment: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      nil
    end

    private

    attr_reader :message_data, :type, :file_name, :request, :raw_media

    # -------------------------------------------------------------------
    # CONFIG
    # -------------------------------------------------------------------

    def config
      MEDIA_CONFIG[type] || MEDIA_CONFIG['document']
    end

    def media_key_base64
      raw_media[:mediaKey] || raw_media[:media_key] || raw_media[:mediakey]
    end

    # -------------------------------------------------------------------
    # URL RESOLUTION
    # -------------------------------------------------------------------

    def url
      # PRIORIDADE 1 — URL completa do Baileys (raw_media.url)
      media_url =
        raw_media[:url] ||
        raw_media[:mediaUrl] ||
        raw_media[:media_url]

      if media_url.present?
        Rails.logger.info "[Zaphub] Using full media URL from raw_media"
        return media_url
      end

      # PRIORIDADE 2 — directPath
      direct_path = raw_media[:directPath] || raw_media[:direct_path]
      if direct_path.present?
        built = build_whatsapp_url(direct_path)
        Rails.logger.info "[Zaphub] Using directPath fallback: #{direct_path} -> #{built}"
        return built
      end

      Rails.logger.warn "[Zaphub] No URL and no directPath available"
      nil
    end

    def build_whatsapp_url(path)
      return path if path =~ %r{\Ahttps?://}
      "https://mmg.whatsapp.net#{path}"
    end

    # -------------------------------------------------------------------
    # DOWNLOAD RAW BYTES (SEM GZIP/TRANSFORMAÇÃO)
    # -------------------------------------------------------------------

    def fetch_raw_media_bytes(target_url, redirects = 5)
      raise "too many redirects" if redirects <= 0

      uri = URI.parse(target_url)
      req = Net::HTTP::Get.new(uri.request_uri)
      req['Accept-Encoding'] = 'identity'
      req['User-Agent'] = 'ZapHub-raw-media'

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
        http.read_timeout = 60
        http.open_timeout = 30
        http.request(req)
      end

      case response
      when Net::HTTPSuccess
        body = response.body.dup.force_encoding('BINARY')
        [body, response]
      when Net::HTTPRedirection
        location = response['location']
        raise "ZapHub redirect without location" if location.blank?

        next_url = location =~ %r{\Ahttps?://} ? location : URI.join(uri, location).to_s
        fetch_raw_media_bytes(next_url, redirects - 1)
      else
        raise "ZapHub download failed: #{response.code}"
      end
    end

    # -------------------------------------------------------------------
    # NORMALIZAÇÃO DO CIPHERTEXT (HEADER / SOBRA DE BYTES)
    # -------------------------------------------------------------------

    def normalize_cipher_body(body)
      expected = raw_media[:fileLength].to_i
      actual = body.bytesize

      return body if expected <= 0

      if actual == expected
        Rails.logger.info "[Zaphub] Cipher body length OK (#{actual})"
        return body
      end

      if actual < expected
        Rails.logger.error "[Zaphub] ciphertext truncated: #{actual} < #{expected}"
        raise "ciphertext truncated: #{actual} < #{expected}"
      end

      extra = actual - expected
      if extra > 64
        Rails.logger.warn "[Zaphub] Unexpected extra bytes (#{extra}); keeping full body and letting sha256 validate"
        return body
      end

      Rails.logger.warn "[Zaphub] body has #{extra} extra bytes (#{actual} vs #{expected}); trying to locate encrypted segment via fileEncSha256"

      target_sha_b64 = raw_media[:fileEncSha256]
      unless target_sha_b64.present?
        Rails.logger.warn "[Zaphub] No fileEncSha256; trimming to first #{expected} bytes heuristically"
        return body[0, expected]
      end

      target_sha = Base64.decode64(target_sha_b64)

      first_candidate = body[0, expected]
      last_candidate  = body[-expected, expected]

      if Digest::SHA256.digest(first_candidate) == target_sha
        Rails.logger.info "[Zaphub] fileEncSha256 matched first #{expected} bytes – trimming tail"
        return first_candidate
      elsif Digest::SHA256.digest(last_candidate) == target_sha
        Rails.logger.info "[Zaphub] fileEncSha256 matched last #{expected} bytes – trimming head"
        return last_candidate
      else
        Rails.logger.warn "[Zaphub] Neither head nor tail matched fileEncSha256; keeping full body and skipping sha256 validation"
        @skip_sha_validation = true
        return body
      end
    end

    # -------------------------------------------------------------------
    # VALIDAÇÃO SHA256 DO CIPHERTEXT
    # -------------------------------------------------------------------

    def validate_sha256!(body)
      return if @skip_sha_validation

      expected_b64 = raw_media[:fileEncSha256]
      return if expected_b64.blank?

      expected = Base64.decode64(expected_b64)
      actual   = Digest::SHA256.digest(body)

      if actual != expected
        Rails.logger.error "[Zaphub] fileEncSha256 mismatch — ciphertext altered"
        raise "ciphertext mismatch (fileEncSha256)"
      end

      Rails.logger.info "[Zaphub] fileEncSha256 OK"
    end

    # -------------------------------------------------------------------
    # DECRYPT (FORMATO WHATSAPP / BAILEYS)
    # -------------------------------------------------------------------

    def decrypt(body)
      key_b64 = media_key_base64
      return body if key_b64.blank?

      media_key = Base64.decode64(key_b64)

      info = case type
             when 'image'   then 'WhatsApp Image Keys'
             when 'video'   then 'WhatsApp Video Keys'
             when 'audio'   then 'WhatsApp Audio Keys'
             else                 'WhatsApp Document Keys'
             end

      expanded = OpenSSL::KDF.hkdf(
        media_key,
        length: 112,
        salt: '',
        info: info,
        hash: 'SHA256'
      )

      iv        = expanded[0, 16]
      cipher_key = expanded[16, 32]
      mac_key    = expanded[48, 32]

      # Formato: ciphertext || mac10 (MAC = HMAC_SHA256(mac_key, iv + ciphertext)[0,10])
      raise "ciphertext too short" if body.bytesize <= 10

      mac        = body[-10, 10]
      ciphertext = body[0, body.bytesize - 10]

      computed_mac_full = OpenSSL::HMAC.digest('sha256', mac_key, iv + ciphertext)
      computed_mac      = computed_mac_full[0, 10]

      unless ActiveSupport::SecurityUtils.secure_compare(computed_mac, mac)
        raise "MAC verification failed"
      end

      cipher = OpenSSL::Cipher.new('AES-256-CBC')
      cipher.decrypt
      cipher.key = cipher_key
      cipher.iv  = iv

      decrypted = cipher.update(ciphertext) + cipher.final
      Rails.logger.info "[Zaphub] Decrypted media: encrypted_size=#{body.bytesize}, decrypted_size=#{decrypted.bytesize}"

      decrypted
    rescue OpenSSL::Cipher::CipherError => e
      raise "[Zaphub] AES decryption failed: #{e.message}"
    end

    # -------------------------------------------------------------------
    # METADADOS DO ARQUIVO
    # -------------------------------------------------------------------

    def content_type(response)
      raw_media[:mimeType] ||
        raw_media[:mimetype] ||
        raw_media[:mime_type] ||
        response['content-type'] ||
        config[:default_mime]
    end

    def final_file_name(tempfile, media_url)
      return file_name if file_name.present?
      return raw_media[:fileNameCandidate] if raw_media[:fileNameCandidate].present?

      File.basename(URI.parse(media_url).path)
    rescue
      tempfile.path.split(File::SEPARATOR).last
    end
  end
end
