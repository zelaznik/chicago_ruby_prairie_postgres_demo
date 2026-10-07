require Rails.root.join('db', 'migrate', '20261006171045_create_postgres_encryption_view_for_people_370ed45a8097674b.rb')

class RevertCreatePostgresEncryptionViewForPeople370ed45a8097674b < ActiveRecord::Migration[8.1]
  def change
    revert CreatePostgresEncryptionViewForPeople370ed45a8097674b
  end
end
