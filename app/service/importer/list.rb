module Importer
  class List
    attr_reader :ingredient, :receipe, :ingredient_list

    def initialize(ingredient:, receipe:, ingredient_list:)
      @ingredient = ingredient
      @receipe = receipe
      @ingredient_list = ingredient_list
    end

    def build
      parsed = IngredientParser.new(ingredient_list)
      ::List.new(
        receipe: receipe,
        ingredient: ingredient,
        measure: parsed.measure || 0,
        direction: parsed.direction
      )
    end

    def create
      list = build

      if list.save
        true
      else
        Rails.logger.warn "Could not import list for #{ingredient&.name.inspect} in #{receipe&.title.inspect}: #{list.errors.full_messages.join(', ')}"
        false
      end
    end
  end
end
