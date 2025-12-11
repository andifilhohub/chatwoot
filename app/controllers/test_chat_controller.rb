# frozen_string_literal: true

# Teste simples para verificar se o sistema básico funciona
class TestChatController < ApplicationController
  skip_before_action :authenticate_user!, if: :skip_authentication?, raise: false
  skip_before_action :verify_authenticity_token, raise: false

  def test_message
    Rails.logger.info "🧪 TEST: Enviando mensagem de teste"
    
    # Broadcast de teste
    ActionCable.server.broadcast(
      "internal_chat_1",
      {
        type: 'new_message',
        chat_type: 'general',
        chat_id: 'general',
        message: {
          content: "Mensagem de teste - #{Time.current}",
          sender_id: 999,
          sender_name: 'Sistema de Teste',
          sender_avatar: nil
        },
        timestamp: Time.current.iso8601
      }
    )
    
    render json: { success: true, message: 'Mensagem de teste enviada!' }
  end

  private

  def skip_authentication?
    true
  end
end
