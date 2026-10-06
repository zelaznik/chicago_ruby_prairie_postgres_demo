class EncryptedPostgresViewGenerator::ViewMaker
  class SelectMigration < BaseMigration
    def up
      <<~SQL.strip
        CREATE VIEW "#{view_name}" AS
        SELECT
          #{select_columns.join(",\n  ")}
        FROM
          "#{altered_table_name}";
      SQL
    end

    def down
      <<~SQL.strip
        DROP VIEW #{view_name};
      SQL
    end

    private

    def select_columns
      column_query.map do |row|
        if encrypted_fields.has_key? row['column_name']
          <<~SQL.gsub(/\s+/, ' ').strip
            pgp_sym_decrypt(
              #{row['column_name']}::bytea,
              current_setting('app.encryption_key')
            ) AS #{encrypted_fields.fetch(row['column_name'])}
          SQL
        else
          row['column_name']
        end
      end
    end
  end
end
