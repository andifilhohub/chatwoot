class CreateScheduledMessageJobs < ActiveRecord::Migration[7.1]
  def change
    create_table :scheduled_message_jobs do |t|
      t.bigint :message_id, null: false
      t.string :job_id
      t.string :status
      t.datetime :scheduled_at
      t.datetime :dispatched_at
      t.string :timezone
      t.jsonb :metadata, default: {}, null: false
      t.text :error_message
      t.timestamps
    end

    add_index :scheduled_message_jobs, :message_id
    add_index :scheduled_message_jobs, :scheduled_at
    add_index :scheduled_message_jobs, :status
    add_foreign_key :scheduled_message_jobs, :messages
  end
end
