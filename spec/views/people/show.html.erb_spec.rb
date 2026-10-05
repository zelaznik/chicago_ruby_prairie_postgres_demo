require 'rails_helper'

RSpec.describe "people/show", type: :view do
  before(:each) do
    assign(:person, Person.create!(
      username: "Username",
      status: "MyText",
      ssn: "Ssn"
    ))
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/Username/)
    expect(rendered).to match(/MyText/)
    expect(rendered).to match(/Ssn/)
  end
end
