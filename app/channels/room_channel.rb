class RoomChannel < ApplicationCable::Channel
  # A classe RoomChannel configura o canal de presença para que o Chatwoot rastreie e
  # transmita o status online de usuários e contatos em uma conta específica.
  # Ele utiliza tokens para identificar os fluxos e integra métodos de rastreamento e
  # transmissão de presença para manter todos os clientes atualizados em tempo real
  def subscribed
    # TODO: should we only do ensure stream  if current account is present?
    # for now going ahead with guard clauses in update_subscription and broadcast_presence

    ensure_stream
    current_user
    current_account
    update_subscription
    broadcast_presence
    new_message
  end

  def new_message
    account_id = params[:account_id]
    user_id = params[:user_id]

    Rails.logger.debug { "o usuario é: #{user_id} e a conta é #{account_id}" }

    # unread_messages_private = InternalMessage.where(read: false, account_id: account_id)

    # unread_messages_group = InternalMessagesGroup.where(read: false, account_id: account_id)
    # unread_messages_private + unread_messages_group
    InternalMessageNotification.where(read: false, account_id: account_id, received_id: user_id)
  end

  def update_presence
    update_subscription
    broadcast_presence
  end

  private

  def broadcast_presence
    return if @current_account.blank?

    data = { account_id: @current_account.id, users: ::OnlineStatusTracker.get_available_users(@current_account.id), newMessage: new_message }
    data[:contacts] = ::OnlineStatusTracker.get_available_contacts(@current_account.id) if @current_user.is_a? User
    ActionCable.server.broadcast(@pubsub_token, { event: 'presence.update', data: data })
  end

  def ensure_stream
    @pubsub_token = params[:pubsub_token]
    stream_from @pubsub_token
  end

  def update_subscription
    return if @current_account.blank?

    ::OnlineStatusTracker.update_presence(@current_account.id, @current_user.class.name, @current_user.id)
  end

  def current_user
    @current_user ||= if params[:user_id].blank?
                        ContactInbox.find_by!(pubsub_token: @pubsub_token).contact
                      else
                        User.find_by!(pubsub_token: @pubsub_token, id: params[:user_id])
                      end
  end

  def current_account
    return if current_user.blank?

    @current_account ||= if @current_user.is_a? Contact
                           @current_user.account
                         else
                           @current_user.accounts.find(params[:account_id])
                         end
  end
end