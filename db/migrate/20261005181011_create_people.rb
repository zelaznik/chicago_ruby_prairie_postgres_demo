class CreatePeople < ActiveRecord::Migration[8.1]
  def change
    create_table :people do |t|
      t.text :username
      t.text :status, default: 'active'
      t.text :encrypted_ssn
      t.text :encrypted_ssn_iv

      t.timestamps
    end
  end
end
