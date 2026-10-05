json.extract! person, :id, :username, :status, :ssn, :created_at, :updated_at
json.url person_url(person, format: :json)
