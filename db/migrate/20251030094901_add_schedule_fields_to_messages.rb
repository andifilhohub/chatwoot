class AddScheduleFieldsToMessages < ActiveRecord::Migration[7.0]
  def change
    add_column :messages, :scheduled_at, :datetime
    add_index :messages, [:inbox_id, :scheduled_at]

    change_table :scheduled_message_jobs, bulk: true do |t|
      t.datetime :scheduled_at
      t.datetime :dispatched_at
      t.string :timezone
      t.jsonb :metadata, null: false, default: {}
      t.text :error_message
    end

    add_index :scheduled_message_jobs, :scheduled_at
    add_index :scheduled_message_jobs, :status
  end
end
