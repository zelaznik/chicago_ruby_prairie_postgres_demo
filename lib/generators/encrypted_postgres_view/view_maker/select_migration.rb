class EncryptedPostgresViewGenerator::ViewMaker
  class SelectMigration < BaseMigration
    def up
      <<~SQL.strip
        CREATE VIEW "#{view_name}" AS
        SELECT
          #{select_columns.join(",\n  ")}
        FROM
          "#{altered_table_name}";

        #{column_defaults.join("\n")}
      SQL
    end

    def down
      <<~SQL.strip
        DROP VIEW #{view_name};
      SQL
    end

    private

    # Copy the table's column defaults onto the view so ActiveRecord sees them
    # when introspecting the view (e.g. Person.new.status => 'active')
    def column_defaults
      column_query
        .select { |row| row['column_default'].present? }
        .reject { |row| encrypted_fields.has_key? row['column_name'] }
        .reject { |row| row['column_default'].match?(/^nextval\(/i) }
        .map do |row|
          %(ALTER VIEW "#{view_name}" ALTER COLUMN #{row['column_name']} SET DEFAULT #{row['column_default']};)
        end
    end

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
