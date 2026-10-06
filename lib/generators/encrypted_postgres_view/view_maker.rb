class EncryptedPostgresViewGenerator
  class ViewMaker
    def self.column_query(table_name)
      query = ActiveRecord::Base.connection.execute <<~SQL
        SELECT
          *

        FROM
          information_schema.columns

        WHERE
          table_name = '#{table_name}'
          AND table_schema = 'public'
      SQL
    end

    attr_reader :table_name, :view_name, :column_query, :encrypted_fields, :altered_table_name, :digest

    def initialize(table_name:, altered_table_name: nil, encrypted_fields: {})
      @table_name = table_name
      @altered_table_name = altered_table_name || "#{table_name}_encrypted"
      @view_name = table_name
      @column_query = self.class.column_query(table_name)
      @encrypted_fields = encrypted_fields.stringify_keys
      @digest = SecureRandom.hex[0...16]
    end

    def sql_up
      <<~SQL.strip
        ALTER TABLE #{table_name} RENAME TO #{altered_table_name};

        #{select_migration.up.strip}

        #{insert_migration.up.strip}

        #{update_migration.up.strip}

        #{delete_migration.up.strip}
      SQL
    end

    def sql_down
      <<~SQL.strip
        #{delete_migration.down.strip}

        #{update_migration.down.strip}

        #{insert_migration.down.strip}

        #{select_migration.down.strip}

        ALTER TABLE #{altered_table_name} RENAME TO #{table_name};
      SQL
    end

    private

    def select_migration
      SelectMigration.new(self)
    end

    def update_migration
      UpdateMigration.new(self)
    end

    def delete_migration
      DeleteMigration.new(self)
    end

    def insert_migration
      InsertMigration.new(self)
    end
  end
end
