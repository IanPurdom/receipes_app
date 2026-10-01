module Importer
  class List

    attr_reader :ingredient, :receipe, :ingredient_list
    
    def initialize(ingredient:, receipe:, ingredient_list:)
      @ingredient = ingredient
      @receipe = receipe
      @ingredient_list = ingredient_list
    end
  
    def create 
    
      list = ::List.new(receipe: receipe,
                        ingredient: ingredient,
                        measure: scrap_measure,
                        direction: scrap_direction)
      
      if list.save 
          
        puts "list for ingredient #{ingredient.name} and receipe #{receipe.title}. saved !"
        
        return true

      end

      puts "list not saved because: #{list.errors.full_messages}"

      return false

    end
    
    private 

    def scrap_direction
      ingredient_list.split(',').count == 2 ? ingredient_list.split(',').last : nil 
    end

    def scrap_measure
      scrap_ingredient_measure.reduce(0) { |sum, n| sum.to_r + (special_measures[n] || n.to_r) }
    end

    def scrap_ingredient_measure
      ingredient_list.scan(/\d\b|#{special_measures.keys.map { |c| Regexp.escape(c) }.join('|')}/)
    end

    def special_measures
      { '½' => 1/2r,
        '¾' => 3/4r,
        '¼' => 1/4r,
        '⅓' => 1/3r,
        '⅔' => 2/3r,
        '⅛' => 1/8r }
    end

  end
  
end