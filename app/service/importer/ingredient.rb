module Importer
  class Ingredient

    attr_reader :ingredient_list, :receipe
    
    def initialize(ingredient_list:, receipe:)
      @ingredient_list = ingredient_list
      @receipe = receipe
    end

    def create

      ingredient = ::Ingredient.find_or_initialize_by(name: scrap_ingredient_name) do |ing|
        ing.measure_type = scrap_measure_type
      end

      if ingredient.save
          
          Rails.logger.info "ingredient #{ingredient.name} saved !"

          return ingredient

      end 

      puts "ingredient #{ingredient.name} not save because: #{ingredient.errors.full_messages}"
      
      return false
    
    end
  
    private 

    def scrap_ingredient_name
      name = ingredient_list.split(',').first
      pattern = /\d+|\b(?:#{measure_types.join('|')})s?\b|#{special_characters.map { |c| Regexp.escape(c) }.join('|')}|[[:punct:]]/i
      name.gsub(pattern, '').strip.squeeze(' ')&.singularize
    end

    def scrap_measure_type
      ingredient_list.scan(/\b(?:#{measure_types.join('|')})/).join.split(' ').first&.singularize
    end

    def measure_types
      %w(teaspoon tablespoon cup slice package ounce)
    end

    def special_characters
      %w(½ ¾ ¼ ⅓ ⅔ ⅛)
    end

  end

end