require 'rails_helper'

RSpec.describe 'Internal chat messages API', type: :request do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:headers) { user.create_new_auth_token.merge('ACCEPT' => 'application/json') }
  let(:room) { GeniusCloud::InternalChat::Room.ensure_general!(account) }

  describe 'GET /api/v1/accounts/:account_id/internal_chat/rooms/:room_id/messages' do
    it 'returns messages ordered chronologically' do
      create(:gc_internal_chat_message, room: room, account: account, sender: user, content: 'Hello')

      get "/api/v1/accounts/#{account.id}/internal_chat/rooms/#{room.id}/messages",
          headers: headers,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['messages'].first['content']).to eq('Hello')
    end
  end

  describe 'POST /api/v1/accounts/:account_id/internal_chat/rooms/:room_id/messages' do
    it 'creates a message with content' do
      post "/api/v1/accounts/#{account.id}/internal_chat/rooms/#{room.id}/messages",
           params: { message: { content: 'Hi team' } },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['content']).to eq('Hi team')
    end
  end

  describe 'PATCH /api/v1/accounts/:account_id/internal_chat/rooms/:room_id/messages/:id' do
    it 'updates the message content' do
      message = create(:gc_internal_chat_message, room: room, account: account, sender: user, content: 'Initial')

      patch "/api/v1/accounts/#{account.id}/internal_chat/rooms/#{room.id}/messages/#{message.id}",
            params: { message: { content: 'Updated' } },
            headers: headers,
            as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['content']).to eq('Updated')
      expect(response.parsed_body['edited']).to be(true)
    end
  end

  describe 'DELETE /api/v1/accounts/:account_id/internal_chat/rooms/:room_id/messages/:id' do
    it 'marks the message as deleted' do
      message = create(:gc_internal_chat_message, room: room, account: account, sender: user, content: 'Initial')

      delete "/api/v1/accounts/#{account.id}/internal_chat/rooms/#{room.id}/messages/#{message.id}",
             headers: headers,
             as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['deleted']).to be(true)
    end
  end
end
