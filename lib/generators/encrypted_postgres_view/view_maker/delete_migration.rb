class EncryptedPostgresViewGenerator::ViewMaker
  class DeleteMigration < BaseMigration
    def up
      <<~SQL.strip
        CREATE OR REPLACE RULE #{rule_name} AS
        ON DELETE TO #{view_name} DO INSTEAD (
          DELETE FROM #{altered_table_name} WHERE id = OLD.id;
        );
      SQL
    end

    def down
      <<~SQL.strip
        DROP RULE #{rule_name} ON #{view_name};
      SQL
    end

    private

    def rule_name
      "_before_delete_on_#{altered_table_name}_#{digest}"
    end
  end
end
