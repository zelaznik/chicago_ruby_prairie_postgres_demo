FactoryBot.define do
  factory :person do
    sequence(:username) { |i| "user-#{i}" }
    status { 'active' }
    ssn do
      digits = format("%09d", rand(10 ** 12))
      "#{digits[0, 3]}-#{digits[3, 2]}-#{digits[5, 4]}"
    end
  end
end
