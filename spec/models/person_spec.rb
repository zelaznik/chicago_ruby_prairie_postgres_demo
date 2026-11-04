require 'rails_helper'

RSpec.describe Person, type: :model do
  it_behaves_like 'an_encrypted_postgres_view',
    with_underlying_table: 'people_encrypted',
    with_encrypted_fields: [
      { view: 'ssn', table: 'pg_encrypted_ssn' }
    ]
end
