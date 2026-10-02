require "rails_helper"

RSpec.describe Importer::Receipe do
  let(:receipe_list) do
    {
      "title" => "Golden Sweet Cornbread",
      "cook_time" => 25,
      "prep_time" => 10,
      "ratings" => 4.74,
      "cuisine" => "American",
      "category" => "Cornbread",
      "author" => "bluegirl",
      "image" => "https://example.com/cornbread.jpg"
    }
  end

  before { allow($stdout).to receive(:puts) }

  describe "#create" do
    it "persists the receipe with the attributes from the list" do
      expect { described_class.new(receipe_list).create }.to change(::Receipe, :count).by(1)

      expect(::Receipe.last).to have_attributes(
        title: "Golden Sweet Cornbread",
        cook_time: 25,
        prep_time: 10,
        ratings: 4.74,
        cuisine: "American",
        category: "Cornbread",
        author: "bluegirl",
        image: "https://example.com/cornbread.jpg"
      )
    end

    it "returns the saved receipe" do
      receipe = described_class.new(receipe_list).create

      expect(receipe).to be_a(::Receipe)
      expect(receipe).to be_persisted
    end

    context "when the receipe is invalid" do
      let(:invalid_list) { receipe_list.merge("title" => nil) }

      it "returns false" do
        expect(described_class.new(invalid_list).create).to be(false)
      end

      it "does not persist anything" do
        expect { described_class.new(invalid_list).create }.not_to change(::Receipe, :count)
      end
    end
  end
end
