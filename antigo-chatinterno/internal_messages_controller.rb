class InternalMessagesController < ApplicationController
  before_action :authenticate_user! # Assegure-se de que o usuário está autenticado

  def create
    @message = InternalMessage.new(message_params)
    @message.sender_id = current_user.id # Atribui o ID do usuário atual como remetente

    if @message.save
      ActionCable.server.broadcast('internal_chat_channel', {
                                     user: current_user.name,
                                     content: @message.content,
                                     timestamp: @message.created_at.strftime('%Y-%m-%d %H:%M:%S')
                                   })
      head :ok # Retorna uma resposta de sucesso
    else
      render json: { errors: @message.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def message_params
    params.require(:internal_message).permit(:content)
  end
end
