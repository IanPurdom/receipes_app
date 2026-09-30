module Importer
  class ImporterService

    attr_reader :receipes_list
    
    def initialize(receipes_list)
      @receipes_list = receipes_list
    end

    def import
      receipes_list.each do |receipe_list|
        receipe = Importer::Receipe.new(receipe_list).create

        next unless receipe
        
        receipe_list["ingredients"].each do |ingredient_list|
          ingredient = Importer::Ingredient.new(ingredient_list: ingredient_list,
                                                receipe: receipe)
                                                .create
          
          if ingredient

            list = Importer::List.new(ingredient: ingredient, 
                                      receipe: receipe,
                                      ingredient_list: ingredient_list).create
          
            unless list 
              
              delete_temp_receipe(receipe, ingredient) 
            
            end
          
          end
                                                
        end
        
      end
    
    end

    private 

    def delete_temp_receipe
      receipe.ingredients.destroy_all
      receipe.destroy

      Rails.logger.info 'temp receipe and related ingredients have been deleted'
    end  
  
  end

end