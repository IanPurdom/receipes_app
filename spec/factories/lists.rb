FactoryBot.define do
  factory :list do
    receipe
    ingredient
    measure { 1.0 }
    direction { "Mix well" }
  end
end
