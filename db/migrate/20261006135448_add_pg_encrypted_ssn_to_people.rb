class AddPgEncryptedSsnToPeople < ActiveRecord::Migration[8.1]
  def change
    add_column :people, :pg_encrypted_ssn, :text
  end
end
