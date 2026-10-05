require 'rails_helper'

RSpec.describe "people/edit", type: :view do
  let(:person) {
    Person.create!(
      username: "MyString",
      status: "MyText",
      ssn: "MyString"
    )
  }

  before(:each) do
    assign(:person, person)
  end

  it "renders the edit person form" do
    render

    assert_select "form[action=?][method=?]", person_path(person), "post" do

      assert_select "input[name=?]", "person[username]"

      assert_select "textarea[name=?]", "person[status]"

      assert_select "input[name=?]", "person[ssn]"
    end
  end
end
