require "rails_helper"

RSpec.describe Importer::ImporterService do
  let(:cornbread) do
    {
      "title" => "Cornbread",
      "cook_time" => 25,
      "prep_time" => 10,
      "ratings" => 4.7,
      "cuisine" => "American",
      "category" => "Bread",
      "author" => "bluegirl",
      "image" => "https://example.com/cornbread.jpg",
      "ingredients" => ["1 cup flour", "1 ½ cups milk", "2 eggs"]
    }
  end

  let(:pancakes) do
    cornbread.merge(
      "title" => "Pancakes",
      "ingredients" => ["2 cups flour", "1 cup milk, warmed"]
    )
  end

  before do
    allow($stdout).to receive(:puts)
    allow(Rails.logger).to receive(:info)
  end

  describe "#import" do
    it "creates the receipes" do
      expect { described_class.new([cornbread, pancakes]).import }.to change(::Receipe, :count).by(2)

      expect(::Receipe.pluck(:title)).to contain_exactly("Cornbread", "Pancakes")
    end

    it "creates one list per ingredient of each receipe" do
      expect { described_class.new([cornbread, pancakes]).import }.to change(::List, :count).by(5)

      expect(::Receipe.find_by(title: "Cornbread").lists.count).to eq(3)
      expect(::Receipe.find_by(title: "Pancakes").lists.count).to eq(2)
    end

    it "links each receipe to its ingredients" do
      described_class.new([cornbread]).import

      expect(::Receipe.find_by(title: "Cornbread").ingredients.pluck(:name))
        .to contain_exactly("flour", "milk", "egg")
    end

    it "shares ingredients between receipes" do
      expect { described_class.new([cornbread, pancakes]).import }.to change(::Ingredient, :count).by(3)
    end

    it "stores the measure and direction of each list" do
      described_class.new([pancakes]).import

      milk_list = ::List.joins(:ingredient).find_by(ingredients: { name: "milk" })

      expect(milk_list.measure).to eq(1)
      expect(milk_list.direction.strip).to eq("warmed")
    end

    it "does nothing with an empty list" do
      expect { described_class.new([]).import }.not_to change { [::Receipe.count, ::Ingredient.count, ::List.count] }
    end

    it "does not import ingredients of a receipe that could not be saved" do
      invalid = cornbread.merge("title" => nil)

      expect { described_class.new([invalid]).import }
        .not_to change { [::Receipe.count, ::Ingredient.count, ::List.count] }
    end

    it "keeps importing the following receipes after an invalid one" do
      invalid = cornbread.merge("title" => nil)

      expect { described_class.new([invalid, pancakes]).import }.to change(::Receipe, :count).by(1)

      expect(::Receipe.pluck(:title)).to eq(["Pancakes"])
    end

    it "skips the ingredients that could not be saved without failing the import" do
      receipe = cornbread.merge("ingredients" => ["2 cups", "1 cup flour"])

      expect { described_class.new([receipe]).import }.to change(::List, :count).by(1)

      expect(::Receipe.find_by(title: "Cornbread").ingredients.pluck(:name)).to eq(["flour"])
    end

    context "when a list cannot be saved" do
      let(:single_ingredient) { cornbread.merge("ingredients" => ["1 cup flour"]) }

      before do
        allow_any_instance_of(Importer::List).to receive(:create).and_return(false)
      end

      it "deletes the temporary receipe" do
        described_class.new([single_ingredient]).import

        expect(::Receipe.count).to eq(0)
      end

      it "does not leave any list behind" do
        expect { described_class.new([single_ingredient]).import }.not_to change(::List, :count)
      end
    end
  end
end
