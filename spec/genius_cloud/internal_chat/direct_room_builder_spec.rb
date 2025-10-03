require 'rails_helper'

RSpec.describe GeniusCloud::InternalChat::DirectRoomBuilder do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:target_user) { create(:user, account: account) }

  describe '#find_or_create' do
    it 'creates a new direct room and memberships' do
      room = described_class.new(
        account: account,
        initiating_user: user,
        target_user: target_user
      ).find_or_create

      expect(room).to be_direct
      expect(room.metadata['participant_ids']).to match_array([user.id, target_user.id])
      expect(room.memberships.pluck(:user_id)).to contain_exactly(user.id, target_user.id)
    end

    it 'returns existing room when it already exists' do
      first_room = described_class.new(
        account: account,
        initiating_user: user,
        target_user: target_user
      ).find_or_create

      expect do
        described_class.new(
          account: account,
          initiating_user: target_user,
          target_user: user
        ).find_or_create
      end.not_to change(GeniusCloud::InternalChat::Room, :count)

      expect(first_room.memberships.count).to eq(2)
    end
  end
end
