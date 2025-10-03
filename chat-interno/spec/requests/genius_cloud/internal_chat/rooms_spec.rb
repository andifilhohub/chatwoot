require 'rails_helper'

RSpec.describe 'Internal chat rooms API', type: :request do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:headers) { user.create_new_auth_token.merge('ACCEPT' => 'application/json') }

  describe 'GET /api/v1/accounts/:account_id/internal_chat/rooms' do
    it 'returns rooms accessible to the user' do
      team = create(:team, account: account)
      create(:team_member, team: team, user: user)
      GeniusCloud::InternalChat::DirectRoomBuilder.new(
        account: account,
        initiating_user: user,
        target_user: create(:user, account: account)
      ).find_or_create

      get "/api/v1/accounts/#{account.id}/internal_chat/rooms",
          headers: headers,
          as: :json

      expect(response).to have_http_status(:success)
      payload = response.parsed_body
      room_types = payload['rooms'].map { |room| room['room_type'] }
      expect(room_types).to include('general', 'team', 'direct')
    end
  end

  describe 'POST /api/v1/accounts/:account_id/internal_chat/rooms' do
    let(:other_user) { create(:user, account: account) }

    it 'creates a direct room' do
      post "/api/v1/accounts/#{account.id}/internal_chat/rooms",
           params: { room: { room_type: 'direct', target_user_id: other_user.id } },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:created)
      room = response.parsed_body
      expect(room['room_type']).to eq('direct')
      participant_ids = room['participants'].map { |participant| participant['id'] }
      expect(participant_ids).to include(user.id, other_user.id)
    end
  end
end
