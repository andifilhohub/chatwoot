# frozen_string_literal: true

# == Schema Information
#
# Table name: gc_internal_chat_rooms
#
#  id         :bigint           not null, primary key
#  direct_key :string
#  metadata   :jsonb            not null
#  name       :string
#  room_type  :integer          not null
#  slug       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#  team_id    :bigint
#
# Indexes
#
#  idx_gc_chat_rooms_account_slug           (account_id,slug) UNIQUE
#  idx_gc_chat_rooms_direct_key             (direct_key) UNIQUE
#  idx_gc_chat_rooms_general_per_account    (account_id) UNIQUE WHERE (room_type = 0)
#  idx_gc_chat_rooms_team_per_account       (account_id,team_id) UNIQUE WHERE (room_type = 1)
#  index_gc_internal_chat_rooms_on_team_id  (team_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (team_id => teams.id)
#
class GcInternalChatRoom < ApplicationRecord
  belongs_to :account
  belongs_to :team, optional: true
  has_many :gc_internal_chat_memberships, foreign_key: 'room_id', dependent: :destroy
  has_many :gc_internal_chat_messages, foreign_key: 'room_id', dependent: :destroy
  has_many :users, through: :gc_internal_chat_memberships

  enum room_type: {
    general: 0,
    team: 1,
    direct: 2
  }

  validates :slug, presence: true, uniqueness: { scope: :account_id }
  validates :name, presence: true
  validates :room_type, presence: true
  validates :account_id, uniqueness: true, if: :general?
  validates :team_id, uniqueness: { scope: :account_id }, if: :team?
  validates :direct_key, uniqueness: true, if: :direct?

  scope :for_account, ->(account) { where(account: account) }
  scope :for_user, ->(user) {
    joins(:gc_internal_chat_memberships)
      .where(gc_internal_chat_memberships: { user: user })
  }

  def self.find_or_create_general(account)
    find_or_create_by(account: account, room_type: :general) do |room|
      room.name = 'General'
      room.slug = 'general'
    end
  end

  def self.find_or_create_team_room(team)
    find_or_create_by(account: team.account, team: team, room_type: :team) do |room|
      room.name = team.name
      room.slug = "team-#{team.id}"
    end
  end

  def self.find_or_create_direct_room(account, user1, user2)
    # Create a consistent direct_key regardless of user order
    direct_key = [user1.id, user2.id].sort.join('-')
    
    find_or_create_by(account: account, room_type: :direct, direct_key: direct_key) do |room|
      room.name = "#{user1.name} & #{user2.name}"
      room.slug = "direct-#{direct_key}"
    end
  end

  def add_member(user)
    gc_internal_chat_memberships.find_or_create_by(user: user)
  end

  def remove_member(user)
    gc_internal_chat_memberships.find_by(user: user)&.destroy
  end

  def member?(user)
    gc_internal_chat_memberships.exists?(user: user)
  end

  def last_message
    gc_internal_chat_messages.last
  end

  def unread_count_for(user)
    membership = gc_internal_chat_memberships.find_by(user: user)
    return 0 unless membership

    gc_internal_chat_messages
      .where('created_at > ?', membership.last_read_at || membership.created_at)
      .where.not(user: user)
      .count
  end
end
