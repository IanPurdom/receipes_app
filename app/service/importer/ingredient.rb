module Importer
  class Ingredient

    attr_reader :ingredient_list, :receipe
    
    def initialize(ingredient_list:, receipe:)
      @ingredient_list = ingredient_list
      @receipe = receipe
    end

    def create

      ingredient = ::Ingredient.find_or_initialize_by(name: scan_ingredient_name) do |ing|
        ing.measure_type = scan_measure_type
      end

      if ingredient.save
          
          Rails.logger.info "ingredient #{ingredient.name} saved !"

          return ingredient

      end 

      puts "ingredient #{ingredient.name} not save because: #{ingredient.errors.full_messages}"
      
      return false
    
    end
  
    private 

    def scan_ingredient_name
      pattern = /\d+|\b(?:#{measure_types.join('|')})s?\b|#{special_characters.map { |c| Regexp.escape(c) }.join('|')}|[[:punct:]]/i
      ingredient_list.gsub(pattern, '').strip.squeeze(' ').singularize
    end

    def scan_measure_type
      ingredient_list.scan(/\D+/).join.split(' ').first
    end

    def measure_types
      %w(teaspoon tablespoon cup slice package ounce)
    end

    def special_characters
      %w(½ ¾ ¼ ⅓ ⅔)
    end

  end

end

###3 ripe bananas, mashed"
##6 slices turkey bacon, cut into small pieces
##"½ cup butter, softened"
#1 teaspoon ground cinnamon, or to taste"
#"¼ cup vegetable oil, or as needed"
#"¼ cup butter, divided"
#eggs, lightly beaten
# "( ounce) cans refrigerated biscuit dough, separated and cut into quarters"
## 2 (16 ounce) cans refrigerated biscuit dough"