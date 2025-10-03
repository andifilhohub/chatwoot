require 'rails_helper'

RSpec.describe GeniusCloud::InternalChat::Room do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }

  describe '.ensure_general!' do
    it 'creates a general room for the account' do
      room = described_class.ensure_general!(account)

      expect(room).to be_persisted
      expect(room).to be_general
      expect(room.account_id).to eq(account.id)
      expect(room.slug).to eq('general')
    end

    it 'returns the same room if called multiple times' do
      room = described_class.ensure_general!(account)

      expect { described_class.ensure_general!(account) }.not_to change(described_class, :count)
      expect(described_class.ensure_general!(account)).to eq(room)
    end
  end

  describe '.ensure_team!' do
    it 'creates a team room scoped to the team' do
      room = described_class.ensure_team!(team)

      expect(room).to be_team
      expect(room.account_id).to eq(account.id)
      expect(room.team_id).to eq(team.id)
      expect(room.slug).to eq("team-#{team.id}")
    end
  end

  describe 'validations' do
    it 'requires a direct_key for direct rooms' do
      room = described_class.new(account: account, room_type: :direct)

      expect(room).not_to be_valid
      expect(room.errors[:direct_key]).to be_present
    end

    it 'validates team belongs to the same account' do
      other_team = create(:team)
      room = described_class.new(account: account, room_type: :team, team: other_team)

      expect(room).not_to be_valid
      expect(room.errors[:team]).to be_present
    end
  end
end
