class AddSchedulingFieldsToMessages < ActiveRecord::Migration[7.1]
  def change
    add_column :messages, :schedule_info, :jsonb, default: {}
    add_column :messages, :scheduled_at, :datetime
    add_index :messages, [:inbox_id, :scheduled_at]
  end
end
