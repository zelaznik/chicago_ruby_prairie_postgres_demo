class CreatePeople < ActiveRecord::Migration[8.1]
  def change
    create_table :people do |t|
      t.string :username
      t.text :status
      t.string :ssn

      t.timestamps
    end
  end
end
