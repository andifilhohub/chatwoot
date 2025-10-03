class CreateGcInternalChatRooms < ActiveRecord::Migration[7.0]
  def change
    create_table :gc_internal_chat_rooms do |t|
      t.references :account, null: false, foreign_key: true, index: false
      t.integer :room_type, null: false
      t.references :team, foreign_key: true
      t.string :name
      t.string :slug, null: false
      t.string :direct_key
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :gc_internal_chat_rooms, [:account_id, :slug], unique: true, name: 'idx_gc_chat_rooms_account_slug'
    add_index :gc_internal_chat_rooms, :direct_key, unique: true, name: 'idx_gc_chat_rooms_direct_key'
    add_index :gc_internal_chat_rooms, [:account_id], unique: true, where: 'room_type = 0', name: 'idx_gc_chat_rooms_general_per_account'
    add_index :gc_internal_chat_rooms, [:account_id, :team_id], unique: true, where: 'room_type = 1', name: 'idx_gc_chat_rooms_team_per_account'
  end
end
