require "rails_helper"

RSpec.describe Importer::IngredientParser do
  {
    "water, as needed" => ["water", "as needed"],
    "water as needed" => ["water", "as needed"],
    "hot water or as needed" => ["hot water", "or as needed"],
    "melted butter (or as needed)" => ["melted butter", "or as needed"],
    "salt and pepper to taste" => ["salt and pepper", "to taste"],
    "1 pound sliced pastrami (divided)" => ["sliced pastrami", "divided"],
    "lemon juice (optional)" => ["lemon juice", "optional"],
    "1 As needed Mazola Spray" => ["Mazola Spray", "As needed"],
    "1 egg beaten with" => ["egg", "beaten with"],
    "3 beaten eggs" => ["egg", "beaten"],
    "1 beaten egg white" => ["egg white", "beaten"],
    "2 cups flour, sifted" => ["flour", "sifted"]
  }.each do |line, (name, direction)|
    it "splits #{line.inspect} into #{name.inspect} and #{direction.inspect}" do
      parser = described_class.new(line)

      expect(parser.name).to eq(name)
      expect(parser.direction).to eq(direction)
    end
  end
end
