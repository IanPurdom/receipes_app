require "rails_helper"

RSpec.describe Importer::List do
  let(:receipe) { create(:receipe) }
  let(:ingredient) { create(:ingredient, name: "flour") }

  def build_importer(ingredient_list)
    described_class.new(ingredient: ingredient, receipe: receipe, ingredient_list: ingredient_list)
  end

  before { allow($stdout).to receive(:puts) }

  describe "#create" do
    it "creates a list linking the receipe and the ingredient" do
      expect { build_importer("1 cup flour").create }.to change(::List, :count).by(1)

      expect(::List.last).to have_attributes(receipe: receipe, ingredient: ingredient)
    end

    it "returns true when the list is saved" do
      expect(build_importer("1 cup flour").create).to be(true)
    end

    describe "measure" do
      {
        "1 cup flour" => 1,
        "2 cups flour" => 2,
        "10 cups flour" => 10,
        "12 cups flour" => 12,
        "3 to 4 cups flour" => 3,
        "8-10 popsicle sticks" => 8,
        "3 to 4 capsules vitamin E oil" => 3,
        "½ cup flour" => 0.5,
        "¾ cup flour" => 0.75,
        "¼ cup flour" => 0.25,
        "⅓ cup flour" => (1 / 3r),
        "⅔ cup flour" => (2 / 3r),
        "⅛ cup flour" => 0.125,
        "⅝ cup flour" => 0.625,
        "1 ½ cups flour" => 1.5,
        "3 ½ teaspoons flour" => 3.5,
        "1 1/2 cups flour" => 1.5,
        "3 (12 ounce) packages refrigerated biscuit dough" => 3
      }.each do |ingredient_list, expected|
        it "computes #{expected.inspect} for #{ingredient_list.inspect}" do
          build_importer(ingredient_list).create

          expect(::List.last.measure).to be_within(0.001).of(expected)
        end
      end

      it "defaults to 0 when the ingredient has no quantity" do
        build_importer("salt").create

        expect(::List.last.measure).to eq(0)
      end
    end

    describe "direction" do
      it "is the part after the comma" do
        build_importer("1 cup flour, sifted").create

        expect(::List.last.direction.strip).to eq("sifted")
      end

      it "is nil when there is no comma" do
        build_importer("1 cup flour").create

        expect(::List.last.direction).to be_nil
      end

      it "keeps the rest of the direction when there are several commas" do
        build_importer("1 cup flour, sifted, packed").create

        expect(::List.last.direction).to eq("sifted, packed")
      end
    end

    context "when the list cannot be saved" do
      it "returns false" do
        importer = described_class.new(ingredient: build(:ingredient), receipe: nil, ingredient_list: "1 cup flour")

        expect(importer.create).to be(false)
      end

      it "does not persist anything" do
        importer = described_class.new(ingredient: build(:ingredient), receipe: nil, ingredient_list: "1 cup flour")

        expect { importer.create }.not_to change(::List, :count)
      end
    end
  end
end
