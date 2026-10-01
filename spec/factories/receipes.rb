FactoryBot.define do
  factory :receipe do
    sequence(:title) { |n| "Receipe #{n}" }
    cook_time { 30 }
    prep_time { 15 }
    ratings { 4.5 }
    cuisine { "French" }
    category { "Dinner" }
    author { "Test Author" }
    image { "https://example.com/image.jpg" }
  end
end
