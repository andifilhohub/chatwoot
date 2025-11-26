class AddCnpjToAccounts < ActiveRecord::Migration[7.1]
  def change
    add_column :accounts, :cnpj, :string, null: true
  end
end
