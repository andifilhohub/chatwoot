# frozen_string_literal: true

# == Schema Information
#
# Table name: gc_internal_chat_messages
#
#  id              :bigint           not null, primary key
#  content         :text
#  deleted_at      :datetime
#  edited_at       :datetime
#  metadata        :jsonb            not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  conversation_id :bigint
#  deleted_by_id   :bigint
#  edited_by_id    :bigint
#  room_id         :bigint           not null
#  sender_id       :bigint           not null
#
# Indexes
#
#  index_gc_internal_chat_messages_on_account_id              (account_id)
#  index_gc_internal_chat_messages_on_conversation_id         (conversation_id)
#  index_gc_internal_chat_messages_on_deleted_at              (deleted_at)
#  index_gc_internal_chat_messages_on_deleted_by_id           (deleted_by_id)
#  index_gc_internal_chat_messages_on_edited_by_id            (edited_by_id)
#  index_gc_internal_chat_messages_on_room_id                 (room_id)
#  index_gc_internal_chat_messages_on_room_id_and_created_at  (room_id,created_at)
#  index_gc_internal_chat_messages_on_sender_id               (sender_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (deleted_by_id => users.id)
#  fk_rails_...  (edited_by_id => users.id)
#  fk_rails_...  (room_id => gc_internal_chat_rooms.id)
#  fk_rails_...  (sender_id => users.id)
#
class GcInternalChatMessage < ApplicationRecord
  belongs_to :room, class_name: 'GcInternalChatRoom', foreign_key: 'room_id', optional: true
  belongs_to :account
  belongs_to :sender, class_name: 'User'
  belongs_to :conversation, optional: true
  belongs_to :edited_by, class_name: 'User', optional: true
  belongs_to :deleted_by, class_name: 'User', optional: true

  validates :content, presence: true, unless: :deleted?
  validates :account_id, presence: true
  validates :sender_id, presence: true

  scope :active, -> { where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :for_room, ->(room) { where(room: room) }

  def deleted?
    deleted_at.present?
  end

  def edited?
    edited_at.present?
  end

  def soft_delete(user)
    update!(
      deleted_at: Time.current,
      deleted_by: user,
      content: nil
    )
  end

  def edit_content(new_content, user)
    update!(
      content: new_content,
      edited_at: Time.current,
      edited_by: user
    )
  end

  def as_json(options = {})
    super(options).merge(
      sender: {
        id: sender.id,
        name: sender.name,
        avatar_url: sender.avatar_url
      },
      edited: edited?,
      deleted: deleted?
    )
  end
end
