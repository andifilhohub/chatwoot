class AddMessagePrefixToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :message_prefix, :text
    add_column :users, :enable_message_prefix, :boolean
  end
end
