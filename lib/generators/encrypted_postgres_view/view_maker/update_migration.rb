class EncryptedPostgresViewGenerator::ViewMaker
  class UpdateMigration < BaseMigration
    def up
      # Ignore generated columns:
      original_columns = column_query.reject { |row| row['generation_expression'].present? }
      plain_text_columns = original_columns.reject { |row| encrypted_fields.has_key? row['column_name'] }
      encrypted_columns  = original_columns.select { |row| encrypted_fields.has_key? row['column_name'] }

      update_plain_text_columns = plain_text_columns.map do |row|
        "#{row['column_name']} = NEW.#{row['column_name']}"
      end

      update_encrypted_columns = encrypted_columns.map do |row|
        f = encrypted_fields[row['column_name']]

        <<-SQL.split("\n").map { |r| r.gsub(/^      /, '') }.join("\n").strip
          IF (NEW.#{f} IS DISTINCT FROM OLD.#{f}) THEN
            UPDATE #{altered_table_name}
            SET #{row['column_name']} = pgp_sym_encrypt(
              NEW.#{f}::text,
              current_setting('app.encryption_key')
            )
            WHERE id = NEW.id;
          END IF;
        SQL
      end

      <<~SQL.strip
        CREATE FUNCTION #{function_name}() RETURNS TRIGGER AS $$
          BEGIN
            UPDATE
              "#{altered_table_name}"
            SET
              #{update_plain_text_columns.join(",\n      ")}
            WHERE
              id = NEW.id;

            #{update_encrypted_columns.join("\n\n    ")}

            RETURN NEW;
          END;
        $$ LANGUAGE 'plpgsql';

        CREATE TRIGGER #{trigger_name}
        INSTEAD OF UPDATE ON #{view_name}
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

    def function_name
      "#{view_name}_update_#{digest}"
    end

    def trigger_name
      "trg_instead_of_update_on_#{altered_table_name}_#{digest}"
    end
  end
end
