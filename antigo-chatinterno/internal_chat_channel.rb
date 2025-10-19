class InternalChatChannel < ApplicationCable::Channel
  def subscribed
    stream_from "internal_chat_#{params[:room]}"
  end

  def unsubscribed
    # Qualquer cleanup necessário quando o canal for desconectado
  end

  def send_message(data)
    ActionCable.server.broadcast("internal_chat_#{params[:room]}", message: data['message'], user: current_user.name)
  end
end
