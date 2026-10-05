class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  attr_encrypted_options.merge! key: ENV.fetch('ATTRIBUTE_ENCRYPTION_KEY')
end
