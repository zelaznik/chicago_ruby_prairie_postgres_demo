class EncryptedPostgresViewGenerator < Rails::Generators::Base
  source_root File.expand_path('templates', __dir__)

  class_option :table_name, type: :string
  class_option :altered_table_name, type: :string
  class_option :encrypted_fields, type: :string

  def generate_custom_migration
    if ActiveRecord::Base.connection_pool.migration_context.needs_migration?
      raise RuntimeError.new <<~TXT
        Cannot generate this custom migration while other migrations are pending.
      TXT
    end

    field_options = JSON.parse(options.fetch('encrypted_fields'))
    encrypted_fields = if field_options.is_a?(Array)
      field_options.map { |f| [f.to_sym, "decrypted_#{f}" ] }.to_h
    elsif field_options.is_a?(Hash)
      field_options.symbolize_keys
    else
      raise RuntimeError, "unsupported type for encrypted_fields: #{field_options.class}"
    end

    view_options = {
      table_name: options.fetch('table_name'),
      altered_table_name: options.fetch('altered_table_name', "#{options.fetch('table_name')}_encrypted"),
      encrypted_fields: encrypted_fields
    }

    view_maker = ViewMaker.new(**view_options)

    time_stamp = Time.now.strftime("%Y%m%d%H%M%S")
    model_name = view_maker.table_name.split('/').map(&:camelize).join('__')
    file_name = "#{time_stamp}_create_postgres_encryption_view_for_#{view_maker.table_name}_#{view_maker.digest}.rb"
    suffix = view_maker.digest.capitalize

    create_file File.join('db', 'migrate', file_name), <<~RUBY
      class CreatePostgresEncryptionViewFor#{model_name}#{suffix} < ActiveRecord::Migration[8.1]
        def up
          execute <<~SQL
            #{view_maker.sql_up.strip.indent(6).strip}
          SQL
        end

        def down
          execute <<~SQL
            #{view_maker.sql_down.strip.indent(6).strip}
          SQL
        end
      end
    RUBY
  end
end

# Autoload the other view maker files AFTER the class has been defined
require File.join(Rails.root, 'lib', 'generators', 'encrypted_postgres_view', 'view_maker.rb')

require File.join(Rails.root, 'lib', 'generators', 'encrypted_postgres_view', 'view_maker', 'base_migration.rb')
require File.join(Rails.root, 'lib', 'generators', 'encrypted_postgres_view', 'view_maker', 'delete_migration.rb')
require File.join(Rails.root, 'lib', 'generators', 'encrypted_postgres_view', 'view_maker', 'insert_migration.rb')
require File.join(Rails.root, 'lib', 'generators', 'encrypted_postgres_view', 'view_maker', 'select_migration.rb')
require File.join(Rails.root, 'lib', 'generators', 'encrypted_postgres_view', 'view_maker', 'update_migration.rb')
