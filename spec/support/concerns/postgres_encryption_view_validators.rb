require "rails_helper"

RSpec.shared_examples "an_encrypted_postgres_view" do |**options|
  let(:underlying_table) { options.fetch(:with_underlying_table) }
  let(:view_columns) { described_class.attribute_names.to_set }
  let(:excluded_columns) { options.fetch(:excluding_fields, []).map(&:to_s).to_set }

  let(:table_query) do
    sql = ActiveRecord::Base.sanitize_sql_array([<<~SQL, underlying_table])
      SELECT *
      FROM information_schema.columns
      WHERE table_name = ?
    SQL

    ActiveRecord::Base.connection.execute(sql)
  end

  let(:table_columns) do
    table_query.map { |c| c['column_name'] }.to_set
  end

  let(:decrypted_columns) do
    options.fetch(:with_encrypted_fields).map { |field_pair| field_pair[:view].to_s }.to_set
  end

  let(:encrypted_columns) do
    options.fetch(:with_encrypted_fields).map { |field_pair| field_pair[:table].to_s }.to_set
  end

  let(:generated_columns) do
    table_query
      .select { |c| c['generation_expression'].present? }
      .map { |c| c['column_name'] }
      .to_set
  end

  let(:model) do
    model = FactoryBot.build(described_class.name.underscore)

    # Make sure that all the encrypted columns contain some non-null value
    decrypted_columns.each do |column|
      if model.send(column).nil?
        model.send("#{column}=", FFaker::Name.last_name)
      end
    end

    model
  end

  let(:fields_with_defaults) do
    default_fields = table_query
      .select { |r| r['column_default'].present? }
      .reject { |r| r['column_default'].is_a?(String) && r['column_default'].match(/^nextval\(/i) }
      .map { |r| "#{r['column_default']} AS #{r['column_name']}" }
      .join(", ")

    ActiveRecord::Base.connection.execute("SELECT #{default_fields}").first
  end

  it "specifies a primary key" do
    expect(described_class.primary_key).not_to be_nil
  end

  it "points to a view and not a table" do
    table_type = ActiveRecord::Base.connection.execute(<<~SQL).first['table_type']
      SELECT table_type
      FROM information_schema.tables
      WHERE table_name = '#{described_class.table_name}'
    SQL

    expect(table_type).to eq("VIEW")
  end

  it "loads the correct fields given the underlying table", :aggregate_failures do
    expected_columns = table_columns - excluded_columns - encrypted_columns + decrypted_columns
    expect(view_columns - expected_columns).to be_empty, "unexpected columns found: #{view_columns - expected_columns}"
    expect(expected_columns - view_columns).to be_empty, "missing columns: #{expected_columns - view_columns}"
  end

  it "preserves all the information, whether encrypted or not" do
    original_attributes = model.attributes
    model.save!

    expect(model.id).not_to be_nil
    expect(original_attributes.compact).to eq(
      model.reload.attributes.slice(*original_attributes.compact.keys)
    )
  end

  it "saves the default values for columns where Postgres specifies a default value" do
    fields_with_defaults.each do |field, _|
      model.send("#{field}=", nil)
    end

    model.save(validate: false)
    model.reload

    actual_model_values = fields_with_defaults.keys.map do |key|
      [key, model.read_attribute_before_type_cast(key)]
    end.to_h

    expect(actual_model_values).to eq(fields_with_defaults)
  end

  it "doesn't set any unexpected default values" do
    nullable_fields_without_defaults = table_query
      .reject { |r| r['generation_expression'].present? }
      .select { |r| r['is_nullable'] == 'YES' }
      .select { |r| r['column_default'].nil? }
      .select { |r| model.attributes.has_key? r['column_name'] }
      .map { |r| r['column_name'] }
      .to_set

    fields_with_defaults_after_initialization = described_class
      .new
      .attributes
      .compact
      .keys
      .to_set

    nullable_fields = nullable_fields_without_defaults - fields_with_defaults_after_initialization

    nullable_fields.each do |field|
      model.send "#{field}=", nil
    end

    # Get rid of any ActiveRecord associations here
    # We're just testing whether we can save to the database
    copied_model = model.class.new **model.attributes

    # Just in case any after-initialize callbacks fill out these values
    # We need to set them back to NULL
    nullable_fields.each do |field|
      copied_model.send "#{field}=", nil
    end
    copied_model.save(validate: false)

    filled_in_fields = copied_model
      .slice(*nullable_fields)
      .compact
      .keys
      .to_set

    copied_model.reload

    actual_model_values = (nullable_fields - filled_in_fields).map do |key|
      [key, copied_model.read_attribute_before_type_cast(key)]
    end.to_h

    actual_model_values.delete("id")
    actual_model_values.delete("created_at")
    actual_model_values.delete("updated_at")

    expect(actual_model_values.compact).to eq({})
  end

  it "encrypts the expected encrypted values" do
    original_attributes = model.attributes
    model.save!

    plain_text_values = original_attributes.slice(*decrypted_columns)

    raw_data = ActiveRecord::Base.connection.execute(<<~SQL).first
      SELECT * FROM "#{underlying_table}" WHERE id = #{model.id}
    SQL

    # Make sure that the original values are not being stored
    plain_text_values.each do |attribute, value|
      expect(raw_data[attribute.to_s]).not_to eq(value)
    end
  end

  it "allows the record to be updated" do
    model.save!
    model.reload

    new_attributes = FactoryBot.build(described_class.name.underscore).attributes.compact

    new_attributes.each do |key, value|
      model.send("#{key}=", value)
    end

    modified_attributes = model.attributes

    model.save(validate: false)
    reloaded_attributes = model.reload.attributes

    # ActiveRecord will update these fields, so we exclude them from comparison
    modified_attributes.delete("updated_at")
    reloaded_attributes.delete("updated_at")

    generated_columns.each do |column|
      modified_attributes.delete(column)
      reloaded_attributes.delete(column)
    end

    expect(reloaded_attributes).to eq(modified_attributes)
  end

  it "allows the record to be deleted" do
    model.save!
    model.destroy!

    record = ActiveRecord::Base.connection.execute(<<~SQL).first
      SELECT * FROM "#{underlying_table}" WHERE id = #{model.id}
    SQL

    expect(record).to be_nil
  end
end

