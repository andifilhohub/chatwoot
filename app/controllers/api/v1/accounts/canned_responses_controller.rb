class Api::V1::Accounts::CannedResponsesController < Api::V1::Accounts::BaseController
  before_action :fetch_canned_response, only: [:update, :destroy]

  def index
    render json: canned_responses, methods: [:files_data]
  end

  def create
    @canned_response = Current.account.canned_responses.new(canned_response_attributes)

    ActiveRecord::Base.transaction do
      @canned_response.save!
      process_uploaded_files(@canned_response, uploaded_files_payload)
    end

    render json: @canned_response.reload, methods: [:files_data]
  end

  def update
    ActiveRecord::Base.transaction do
      @canned_response.update!(canned_response_attributes)
      process_uploaded_files(@canned_response, uploaded_files_payload)
    end

    render json: @canned_response.reload, methods: [:files_data]
  end

  def destroy
    @canned_response.destroy!
    head :ok
  end

  private

  def fetch_canned_response
    @canned_response = Current.account.canned_responses.find(params[:id])
  end

  def canned_response_params
    params.require(:canned_response).permit(
      :short_code,
      :content,
      uploaded_files: [
        :blob_id,
        :signed_id,
        :filename,
        :byte_size,
        :file_type,
        :file_url
      ]
    )
  end

  def canned_response_attributes
    canned_response_params.except(:uploaded_files)
  end

  def uploaded_files_payload
    canned_response_params[:uploaded_files]
  end

  def canned_responses
    if params[:search]
      Current.account.canned_responses
             .where('short_code ILIKE :search OR content ILIKE :search', search: "%#{params[:search]}%")
             .order_by_search(params[:search])

    else
      Current.account.canned_responses
    end
  end

  def process_uploaded_files(canned_response, uploaded_files)
    return if uploaded_files.nil?

    uploaded_files = uploaded_files.map(&:to_h)

    retained_blob_ids = []

    uploaded_files.each do |file|
      file = file.with_indifferent_access

      blob_id = file[:blob_id].presence
      signed_id = file[:signed_id].presence

      if blob_id && signed_id.blank?
        retained_blob_ids << blob_id.to_i
        next
      end

      next if signed_id.blank?

      begin
        blob = ActiveStorage::Blob.find_signed(signed_id)
        next if blob.nil?

        canned_response.files.attach(blob)
        retained_blob_ids << blob.id
      rescue ActiveSupport::MessageVerifier::InvalidSignature
        Rails.logger.warn('CannedResponse attachment ignored due to invalid signature')
      end
    end

    canned_response.files.each do |attachment|
      next if retained_blob_ids.include?(attachment.blob_id)

      attachment.purge_later
    end

    canned_response.update_column(:uploaded_files, canned_response.files_data)
  end
end
