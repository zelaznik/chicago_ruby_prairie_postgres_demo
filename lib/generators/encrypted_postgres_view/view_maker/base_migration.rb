class EncryptedPostgresViewGenerator::ViewMaker
  class BaseMigration
    def initialize(viewmaker)
      @view_maker = viewmaker
    end

    def up
      raise NotImplementedError
    end

    def down
      raise NotImplementedError
    end

    private

    attr_reader :view_maker

    delegate  :table_name, :view_name, :column_query, :encrypted_fields,
              :altered_table_name, :digest,
              to: :view_maker
  end
end
