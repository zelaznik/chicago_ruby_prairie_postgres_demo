require 'rails_helper'

RSpec.describe "people/new", type: :view do
  before(:each) do
    assign(:person, Person.new(
      username: "MyString",
      status: "MyText",
      ssn: "MyString"
    ))
  end

  it "renders new person form" do
    render

    assert_select "form[action=?][method=?]", people_path, "post" do

      assert_select "input[name=?]", "person[username]"

      assert_select "textarea[name=?]", "person[status]"

      assert_select "input[name=?]", "person[ssn]"
    end
  end
end
