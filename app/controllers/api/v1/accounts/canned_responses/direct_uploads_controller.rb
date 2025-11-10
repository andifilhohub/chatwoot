class Api::V1::Accounts::CannedResponses::DirectUploadsController < ActiveStorage::DirectUploadsController
  include EnsureCurrentAccountHelper
  before_action :current_account

  def create
    return if @current_account.nil?

    super
  end
end
