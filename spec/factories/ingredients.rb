FactoryBot.define do
  factory :ingredient do
    sequence(:name) { |n| "Ingredient #{n}" }
    measure_type { "cup" }
  end
end
