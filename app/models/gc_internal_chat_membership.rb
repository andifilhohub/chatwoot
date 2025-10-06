# frozen_string_literal: true

# == Schema Information
#
# Table name: gc_internal_chat_memberships
#
#  id           :bigint           not null, primary key
#  last_read_at :datetime
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  room_id      :bigint           not null
#  user_id      :bigint           not null
#
# Indexes
#
#  index_gc_internal_chat_memberships_on_room_and_user  (room_id,user_id) UNIQUE
#  index_gc_internal_chat_memberships_on_room_id        (room_id)
#  index_gc_internal_chat_memberships_on_user_id        (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (room_id => gc_internal_chat_rooms.id)
#  fk_rails_...  (user_id => users.id)
#
class GcInternalChatMembership < ApplicationRecord
  belongs_to :room, class_name: 'GcInternalChatRoom'
  belongs_to :user

  validates :room_id, presence: true
  validates :user_id, presence: true, uniqueness: { scope: :room_id }

  scope :for_user, ->(user) { where(user: user) }
  scope :for_room, ->(room) { where(room: room) }

  def mark_as_read!
    update!(last_read_at: Time.current)
  end

  def unread_messages_count
    return 0 unless last_read_at

    room.gc_internal_chat_messages
        .active
        .where('created_at > ?', last_read_at)
        .where.not(sender: user)
        .count
  end
end
