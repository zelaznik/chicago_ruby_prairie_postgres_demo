class EncryptedPostgresViewGenerator::ViewMaker
  class InsertMigration < BaseMigration
    def up
      <<~SQL.strip
        CREATE FUNCTION #{function_name}() RETURNS TRIGGER AS $$
          BEGIN
            INSERT INTO #{altered_table_name} (
              #{insert_columns.join(",\n").indent(6).strip}
            ) VALUES (
              #{insert_values.join(",\n").indent(6).strip}
            )

            RETURNING id INTO NEW.id;

            RETURN NEW;
          END;
        $$ LANGUAGE 'plpgsql';

        CREATE TRIGGER #{trigger_name}
        INSTEAD OF INSERT ON #{view_name}
        FOR EACH ROW EXECUTE PROCEDURE #{function_name}();
      SQL
    end

    def down
      <<~SQL.strip
        DROP TRIGGER #{trigger_name} ON #{view_name};
        DROP FUNCTION #{function_name};
      SQL
    end

    private

    def trigger_name
      "trg_instead_of_insert_on_#{altered_table_name}_#{digest}"
    end

    def function_name
      "#{view_name}_create_#{digest}"
    end

    def insert_columns
      original_columns.map { |row| row['column_name'] }
    end

    def original_columns
      column_query.reject { |row| row['generation_expression'].present? }
    end

    def insert_values
      original_columns.map do |row|
        if encrypted_fields.has_key? row['column_name']
          decrypted_field_name = encrypted_fields.fetch(row['column_name'])
          <<~SQL.gsub(/\s+/, ' ').strip
            pgp_sym_encrypt(
              NEW.#{decrypted_field_name}::text,
              current_setting('app.encryption_key')
            )
          SQL

        elsif row['is_nullable'] == 'NO' && row['column_default'].present?
          <<~SQL.strip
            COALESCE(NEW.#{row['column_name']}, #{row['column_default']})
          SQL
        elsif row['is_nullable'] == 'YES' && row['column_default'].present?
          raise RuntimeError.new <<~TXT

            The column #{JSON.generate(row['column_name'])} both permits NULL values and has a default value.
            Therefore it's impossible to create an encryption view on top of this table.

            The reason is that when creating a new record, Postgres can't tell whether the field was omitted
            or whether its value was explicitly set to null.

            If you still want to make an encrypted Postgres view for this table, we recommend banning NULL values
            for all columns with default values.
          TXT
        else
          "NEW.#{row['column_name']}"
        end
      end
    end
  end
end
