module Importer
  class Ingredient
    attr_reader :ingredient_list, :receipe

    def initialize(ingredient_list:, receipe:)
      @ingredient_list = ingredient_list
      @receipe = receipe
    end

    def create
      parsed = IngredientParser.new(ingredient_list)
      ingredient = ::Ingredient.find_or_initialize_by(name: parsed.name) do |record|
        record.measure_type = parsed.measure_type
      end

      if ingredient.save
        ingredient
      else
        Rails.logger.warn "Could not import ingredient #{parsed.name.inspect}: #{ingredient.errors.full_messages.join(', ')}"
        false
      end
    end
  end
end
