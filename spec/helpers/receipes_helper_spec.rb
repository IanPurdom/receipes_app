require "rails_helper"

RSpec.describe ReceipesHelper, type: :helper do
  describe "#receipe_image_url" do
    it "returns the default placeholder image when the receipe has no image" do
      receipe = build(:receipe, image: nil)

      expect(helper.receipe_image_url(receipe)).to include("receipe-placeholder")
    end

    it "extracts the real image URL from the imagesvc proxy URL" do
      receipe = build(
        :receipe,
        image: "https://imagesvc.meredithcorp.io/v3/mm/image?url=https%3A%2F%2Fimages.media-allrecipes.com%2Fuserphotos%2F2777.jpg"
      )

      expect(helper.receipe_image_url(receipe)).to eq("https://images.media-allrecipes.com/userphotos/2777.jpg")
    end

    it "returns the original URL as-is when it is not a proxy URL" do
      receipe = build(:receipe, image: "https://example.com/plain-image.jpg")

      expect(helper.receipe_image_url(receipe)).to eq("https://example.com/plain-image.jpg")
    end
  end

  describe "#ingredient_display_name" do
    it "pluralizes the name when there is no unit and the quantity is above 1" do
      expect(helper.ingredient_display_name(3, nil, "egg")).to eq("eggs")
    end

    it "keeps the name singular for a quantity of 1 or less" do
      expect(helper.ingredient_display_name(1, nil, "egg")).to eq("egg")
      expect(helper.ingredient_display_name(0.5, nil, "egg")).to eq("egg")
    end

    it "keeps the name unchanged when a unit is present" do
      expect(helper.ingredient_display_name(2, "cup", "flour")).to eq("flour")
    end

    it "keeps the name unchanged without a quantity" do
      expect(helper.ingredient_display_name(nil, nil, "water")).to eq("water")
    end
  end

  describe "#format_quantity" do
    it "pluralizes the unit when the quantity is above 1" do
      expect(helper.format_quantity(2, "cup")).to eq("2 cups")
      expect(helper.format_quantity(1.5, "clove")).to eq("1.5 cloves")
    end

    it "keeps the unit singular for 1 or less" do
      expect(helper.format_quantity(0.5, "cup")).to eq("0.5 cup")
    end

    it "formats a whole measure with its unit" do
      expect(helper.format_quantity(1, "cup")).to eq("1 cup")
    end

    it "rounds a decimal measure to two digits" do
      expect(helper.format_quantity(0.667, "cup")).to eq("0.67 cup")
    end
  end

  describe "#total_time" do
    it "sums prep and cook time" do
      receipe = build(:receipe, prep_time: 10, cook_time: 20)

      expect(helper.total_time(receipe)).to eq(30)
    end

    it "returns nil when both times are blank" do
      receipe = build(:receipe, prep_time: nil, cook_time: nil)

      expect(helper.total_time(receipe)).to be_nil
    end
  end
end
