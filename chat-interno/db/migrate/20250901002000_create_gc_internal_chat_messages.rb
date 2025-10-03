class CreateGcInternalChatMessages < ActiveRecord::Migration[7.0]
  def change
    create_table :gc_internal_chat_messages do |t|
      t.references :room, null: false, foreign_key: { to_table: :gc_internal_chat_rooms }
      t.references :account, null: false, foreign_key: true
      t.references :sender, null: false, foreign_key: { to_table: :users }
      t.references :conversation, foreign_key: true
      t.text :content
      t.jsonb :metadata, null: false, default: {}
      t.datetime :edited_at
      t.references :edited_by, foreign_key: { to_table: :users }
      t.datetime :deleted_at
      t.references :deleted_by, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :gc_internal_chat_messages, [:room_id, :created_at]
    add_index :gc_internal_chat_messages, :deleted_at
  end
end
