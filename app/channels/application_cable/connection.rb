class ApplicationCable::Connection < ActionCable::Connection::Base
  identified_by :current_user

  def connect
    self.current_user = find_verified_user
    Rails.logger.info "🔌 ApplicationCable: User #{current_user&.id} connected"
  end

  private

  def find_verified_user
    # Tentar autenticar via pubsub_token (query params)
    if request.params[:pubsub_token].present?
      user = User.find_by(pubsub_token: request.params[:pubsub_token])
      return user if user
      
      # Tentar como SuperAdmin
      user = SuperAdmin.find_by(pubsub_token: request.params[:pubsub_token])
      return user if user
    end

    # Tentar autenticar via sessão (cookie)
    if request.session['warden.user.user.key'].present?
      user_id = request.session['warden.user.user.key'][0][0]
      user = User.find_by(id: user_id)
      return user if user
    end

    Rails.logger.error "❌ ApplicationCable: Authentication failed"
    reject_unauthorized_connection
  rescue => e
    Rails.logger.error "❌ ApplicationCable: Error finding user: #{e.message}"
    reject_unauthorized_connection
  end
end
