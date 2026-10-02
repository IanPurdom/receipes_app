module Importer
  class ImporterService
    attr_reader :receipes_list

    def initialize(receipes_list)
      @receipes_list = receipes_list
    end

    def import
      receipes_list.each do |receipe_list|
        ActiveRecord::Base.transaction do
          receipe = Importer::Receipe.new(receipe_list).create
          next unless receipe

          Array(receipe_list["ingredients"]).each do |ingredient_list|
            ingredient = Importer::Ingredient.new(
              ingredient_list: ingredient_list,
              receipe: receipe
            ).create

            next unless ingredient

            list = Importer::List.new(
              ingredient: ingredient,
              receipe: receipe,
              ingredient_list: ingredient_list
            ).create

            unless list
              Rails.logger.warn "Rolling back import of receipe #{receipe.title.inspect} because an ingredient list could not be saved"
              raise ActiveRecord::Rollback
            end
          end
        end
      end
    end
  end
end
