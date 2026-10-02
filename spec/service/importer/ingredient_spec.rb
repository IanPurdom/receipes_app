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

    it "singularizes the name" do
      ingredient = build_importer("3 eggs").create

      expect(ingredient.name).to eq("egg")
    end

    it "ignores everything after the first comma when computing the name" do
      ingredient = build_importer("1 cup butter, melted").create

      expect(ingredient.name).to eq("butter")
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
