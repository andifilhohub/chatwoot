class CreateGcInternalChatMemberships < ActiveRecord::Migration[7.0]
  def change
    create_table :gc_internal_chat_memberships do |t|
      t.references :room, null: false, foreign_key: { to_table: :gc_internal_chat_rooms }
      t.references :user, null: false, foreign_key: true
      t.datetime :last_read_at

      t.timestamps
    end

    add_index :gc_internal_chat_memberships, [:room_id, :user_id], unique: true, name: 'index_gc_internal_chat_memberships_on_room_and_user'
  end
end
