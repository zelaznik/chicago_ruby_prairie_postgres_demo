require 'rails_helper'

RSpec.describe "people/index", type: :view do
  before(:each) do
    assign(:people, [
      Person.create!(
        username: "Username",
        status: "MyText",
        ssn: "Ssn"
      ),
      Person.create!(
        username: "Username",
        status: "MyText",
        ssn: "Ssn"
      )
    ])
  end

  it "renders a list of people" do
    render
    cell_selector = 'div>p'
    assert_select cell_selector, text: Regexp.new("Username".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("MyText".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("Ssn".to_s), count: 2
  end
end
