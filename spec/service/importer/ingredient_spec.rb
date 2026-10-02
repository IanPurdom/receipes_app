require "rails_helper"

RSpec.describe Importer::Ingredient do
  let(:receipe) { create(:receipe) }

  def build_importer(ingredient_list)
    described_class.new(ingredient_list: ingredient_list, receipe: receipe)
  end

  before { allow($stdout).to receive(:puts) }

  describe "#create" do
    it "creates the ingredient and returns it" do
      ingredient = nil

      expect { ingredient = build_importer("1 egg").create }.to change(::Ingredient, :count).by(1)

      expect(ingredient).to be_persisted
      expect(ingredient.name).to eq("egg")
    end

    it "strips quantities and measure types from the name" do
      ingredient = build_importer("2 cups milk").create

      expect(ingredient.name).to eq("milk")
    end

    it "strips fraction characters from the name" do
      ingredient = build_importer("½ cup margarine").create

      expect(ingredient.name).to eq("margarine")
    end

    it "preserves punctuation that belongs to the ingredient name" do
      ingredient = build_importer("1 cup all-purpose flour").create

      expect(ingredient.name).to eq("all-purpose flour")
    end

    it "removes package-size details from the ingredient name" do
      ingredient = build_importer("3 (12 ounce) packages refrigerated biscuit dough").create

      expect(ingredient.name).to eq("refrigerated biscuit dough")
    end

    it "singularizes the name" do
      ingredient = build_importer("3 eggs").create

      expect(ingredient.name).to eq("egg")
    end

    it "ignores everything after the first comma when computing the name" do
      ingredient = build_importer("1 cup butter, melted").create

      expect(ingredient.name).to eq("butter")
    end

    it "preserves hyphens and apostrophes in ingredient names" do
      ingredient = build_importer("1 teaspoon baker's chocolate").create

      expect(ingredient.name).to eq("baker's chocolate")
    end

    it "ignores the measure type case" do
      ingredient = build_importer("2 Tablespoons sugar").create

      expect(ingredient.name).to eq("sugar")
    end

    it "stores the measure type of the ingredient" do
      ingredient = build_importer("1 cup milk").create

      expect(ingredient.measure_type).to eq("cup")
    end

    it "singularizes the measure type" do
      ingredient = build_importer("2 teaspoons salt").create

      expect(ingredient.measure_type).to eq("teaspoon")
    end

    it "extracts a package measure after parenthetical package size" do
      ingredient = build_importer("3 (12 ounce) packages refrigerated biscuit dough").create

      expect(ingredient.measure_type).to eq("package")
    end

    it "extracts a package unit expressed as either a can or bottle" do
      ingredient = build_importer("1 (12 fluid ounce) can or bottle beer").create

      expect(ingredient.measure_type).to eq("can")
    end

    it "removes abbreviated fluid-ounce package sizes" do
      ingredient = build_importer("1 (16 fl oz) bottle salad dressing").create

      expect(ingredient.name).to eq("salad dressing")
      expect(ingredient.measure_type).to eq("bottle")
    end

    it "extracts the amount and unit from a quantity range" do
      ingredient = build_importer("3 to 4 capsules vitamin E oil").create

      expect(ingredient.name).to eq("vitamin E oil")
      expect(ingredient.measure_type).to eq("capsule")
    end

    it "leaves the measure type empty when there is none" do
      ingredient = build_importer("1 egg").create

      expect(ingredient.measure_type).to be_nil
    end

    context "when the ingredient already exists" do
      let!(:existing) { create(:ingredient, name: "milk", measure_type: "cup") }

      it "reuses the existing ingredient" do
        ingredient = nil

        expect { ingredient = build_importer("2 cups milk").create }.not_to change(::Ingredient, :count)

        expect(ingredient).to eq(existing)
      end

      it "does not overwrite the existing measure type" do
        build_importer("2 tablespoons milk").create

        expect(existing.reload.measure_type).to eq("cup")
      end
    end

    context "when the ingredient name is blank" do
      it "returns false" do
        expect(build_importer("2 cups").create).to be(false)
      end

      it "does not persist anything" do
        expect { build_importer("2 cups").create }.not_to change(::Ingredient, :count)
      end
    end
  end
end
