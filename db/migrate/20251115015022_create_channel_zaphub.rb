class CreateChannelZaphub < ActiveRecord::Migration[7.1]
  def change
    create_table :channel_zaphub do |t|
      t.integer :account_id, null: false
      t.string :api_key
      t.string :base_url
      t.string :session_id
      t.string :webhook_url
      t.text :qr_code_data
      t.string :status, default: 'pending'
      t.jsonb :additional_attributes, default: {}
      t.datetime :connected_at
      t.timestamps

      t.index :account_id
      t.index :session_id, unique: true
    end
  end
end
