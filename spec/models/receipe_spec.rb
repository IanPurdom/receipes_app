require "rails_helper"

RSpec.describe Receipe, type: :model do
  describe "validations" do
    it "requires a title" do
      receipe = build(:receipe, title: nil)
      expect(receipe).not_to be_valid
      expect(receipe.errors[:title]).to include("can't be blank")
    end
  end

  describe "associations" do
    it "has many ingredients through lists" do
      receipe = create(:receipe)
      tomato = create(:ingredient, name: "Tomato")
      create(:list, receipe: receipe, ingredient: tomato)

      expect(receipe.ingredients).to contain_exactly(tomato)
    end

    it "destroys dependent lists when the receipe is destroyed" do
      receipe = create(:receipe)
      list = create(:list, receipe: receipe)

      expect { receipe.destroy }.to change(List, :count).by(-1)
      expect { list.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe ".with_any_ingredients" do
    let!(:tomato) { create(:ingredient, name: "Tomato") }
    let!(:garlic) { create(:ingredient, name: "Garlic") }
    let!(:basil) { create(:ingredient, name: "Basil") }

    let!(:receipe_with_tomato) { create(:receipe, title: "Tomato soup") }
    let!(:receipe_with_garlic) { create(:receipe, title: "Garlic bread") }
    let!(:receipe_with_basil) { create(:receipe, title: "Basil pesto") }

    before do
      create(:list, receipe: receipe_with_tomato, ingredient: tomato)
      create(:list, receipe: receipe_with_garlic, ingredient: garlic)
      create(:list, receipe: receipe_with_basil, ingredient: basil)
    end

    it "returns receipes containing at least one of the given ingredients" do
      result = Receipe.with_any_ingredients(%w[Tomato Garlic])

      expect(result).to contain_exactly(receipe_with_tomato, receipe_with_garlic)
    end

    it "returns no receipe when no ingredient matches" do
      result = Receipe.with_any_ingredients(["Unknown"])

      expect(result).to be_empty
    end

    it "matches ingredient names regardless of case" do
      result = Receipe.with_any_ingredients(["TOMATO", "garlic"])

      expect(result).to contain_exactly(receipe_with_tomato, receipe_with_garlic)
    end

    it "does not return duplicate receipes when it matches multiple ingredients of the same receipe" do
      create(:list, receipe: receipe_with_tomato, ingredient: garlic)

      result = Receipe.with_any_ingredients(%w[Tomato Garlic])

      expect(result.to_a.size).to eq(result.to_a.uniq.size)
    end
  end

  describe ".with_all_ingredients" do
    let!(:tomato) { create(:ingredient, name: "Tomato") }
    let!(:garlic) { create(:ingredient, name: "Garlic") }
    let!(:basil) { create(:ingredient, name: "Basil") }

    let!(:receipe_with_both) { create(:receipe, title: "Tomato and garlic sauce") }
    let!(:receipe_with_tomato_only) { create(:receipe, title: "Tomato soup") }

    before do
      create(:list, receipe: receipe_with_both, ingredient: tomato)
      create(:list, receipe: receipe_with_both, ingredient: garlic)
      create(:list, receipe: receipe_with_both, ingredient: basil)

      create(:list, receipe: receipe_with_tomato_only, ingredient: tomato)
    end

    it "returns only receipes containing all the given ingredients" do
      result = Receipe.with_all_ingredients(%w[Tomato Garlic])

      expect(result.to_a).to contain_exactly(receipe_with_both)
    end

    it "returns an empty result when no receipe contains all ingredients" do
      result = Receipe.with_all_ingredients(%w[Tomato Garlic Unknown])

      expect(result.to_a).to be_empty
    end

    it "deduplicates the given ingredient names before counting" do
      result = Receipe.with_all_ingredients(%w[Tomato Tomato])

      expect(result.to_a).to contain_exactly(receipe_with_both, receipe_with_tomato_only)
    end

    it "matches ingredient names regardless of case" do
      result = Receipe.with_all_ingredients(%w[TOMATO garlic])

      expect(result.to_a).to contain_exactly(receipe_with_both)
    end
  end

  describe ".with_max_total_time" do
    let!(:quick_receipe) { create(:receipe, title: "Quick toast", prep_time: 5, cook_time: 5) }
    let!(:long_receipe) { create(:receipe, title: "Slow roast", prep_time: 30, cook_time: 120) }
    let!(:receipe_without_times) { create(:receipe, title: "Mystery dish", prep_time: nil, cook_time: nil) }

    it "returns receipes whose combined prep and cook time is within the limit" do
      result = Receipe.with_max_total_time(10)

      expect(result.to_a).to include(quick_receipe)
      expect(result.to_a).not_to include(long_receipe)
    end

    it "excludes receipes whose combined time exceeds the limit" do
      result = Receipe.with_max_total_time(10)

      expect(result.to_a).not_to include(long_receipe)
    end

    it "treats missing prep/cook times as 0" do
      result = Receipe.with_max_total_time(0)

      expect(result.to_a).to include(receipe_without_times)
    end
  end
end
