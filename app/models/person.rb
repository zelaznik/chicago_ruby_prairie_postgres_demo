class Person < ApplicationRecord
  self.primary_key = :id
  attr_encrypted :ssn
end
