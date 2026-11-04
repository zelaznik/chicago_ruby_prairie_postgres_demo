class InstallPgcrypto < ActiveRecord::Migration[8.1]
  def up
    execute "CREATE EXTENSION IF NOT EXISTS pgcrypto"
  end

  def down
    execute "DROP EXTENSION IF EXISTS pgcrypto"
  end
end
