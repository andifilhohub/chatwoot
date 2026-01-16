class SetAutoOfflineDefaultFalse < ActiveRecord::Migration[7.0]
  def change
    change_column_default :account_users, :auto_offline, from: true, to: false
  end
end
