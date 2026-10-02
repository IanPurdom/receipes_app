module Importer
  class ImporterService
    BATCH_SIZE = 250
    INSERT_BATCH_SIZE = 1_000

    attr_reader :receipes_list

    def initialize(receipes_list)
      @receipes_list = receipes_list
    end

    def import
      @ingredient_ids = ::Ingredient.pluck(:name, :id).to_h
      receipes_list.each_slice(BATCH_SIZE) do |receipe_batch|
        import_batch(receipe_batch)
      end
    end

    private

    def import_batch(receipe_batch)
      prepared_receipes = receipe_batch.filter_map { |input| prepare_receipe(input) }
      return if prepared_receipes.empty?

      ActiveRecord::Base.transaction do
        ingredient_records = prepare_ingredients(prepared_receipes)
        persist_ingredients(ingredient_records)
        persist_receipes(prepared_receipes)
        persist_lists(prepared_receipes)
      end
    end

    def prepare_receipe(input)
      receipe = Importer::Receipe.new(input).build
      unless receipe.valid?
        Rails.logger.warn "Could not import receipe #{receipe.title.inspect}: #{receipe.errors.full_messages.join(', ')}"
        return
      end

      prepared = { receipe: receipe, ingredients: [], lists: [] }
      Array(input["ingredients"]).each do |ingredient_description|
        ingredient = Importer::Ingredient.new(
          ingredient_list: ingredient_description,
          receipe: receipe
        ).build

        unless ingredient.valid?
          Rails.logger.warn "Could not import ingredient #{ingredient.name.inspect}: #{ingredient.errors.full_messages.join(', ')}"
          next
        end

        list = Importer::List.new(
          ingredient: ingredient,
          receipe: receipe,
          ingredient_list: ingredient_description
        ).build

        unless list.valid?
          Rails.logger.warn "Could not import list for #{ingredient.name.inspect} in #{receipe.title.inspect}: #{list.errors.full_messages.join(', ')}"
          Rails.logger.warn "Skipping receipe #{receipe.title.inspect} because an ingredient list is invalid"
          return
        end

        prepared[:ingredients] << ingredient
        prepared[:lists] << list
      end

      prepared
    end

    def prepare_ingredients(prepared_receipes)
      prepared_receipes.flat_map { |prepared| prepared[:ingredients] }
                       .uniq(&:name)
                       .reject { |ingredient| @ingredient_ids.key?(ingredient.name) }
    end

    def persist_ingredients(ingredients)
      return if ingredients.empty?

      ids = next_ids(::Ingredient, ingredients.length)
      rows = ingredients.zip(ids).map do |ingredient, id|
        @ingredient_ids[ingredient.name] = id
        model_row(ingredient).merge(id: id)
      end
      insert_in_batches(::Ingredient, rows)
    end

    def persist_receipes(prepared_receipes)
      ids = next_ids(::Receipe, prepared_receipes.length)
      rows = prepared_receipes.zip(ids).map do |prepared, id|
        prepared[:receipe].id = id
        model_row(prepared[:receipe]).merge(id: id)
      end
      insert_in_batches(::Receipe, rows)
    end

    def persist_lists(prepared_receipes)
      rows = prepared_receipes.flat_map do |prepared|
        prepared[:lists].map do |list|
          {
            receipe_id: prepared[:receipe].id,
            ingredient_id: @ingredient_ids.fetch(list.ingredient.name),
            measure: list.measure,
            direction: list.direction
          }
        end
      end
      insert_in_batches(::List, rows)
    end

    def model_row(record)
      timestamp = Time.current
      record.attributes.symbolize_keys.except(:id, :created_at, :updated_at).merge(
        created_at: timestamp,
        updated_at: timestamp
      )
    end

    def next_ids(model, count)
      return [] if count.zero?

      connection = model.connection
      sequence = connection.pk_and_sequence_for(model.table_name)&.last
      raise "No primary-key sequence found for #{model.table_name}" unless sequence

      connection.select_values(
        "SELECT nextval(#{connection.quote(sequence.to_s)}) FROM generate_series(1, #{Integer(count)})"
      ).map!(&:to_i)
    end

    def insert_in_batches(model, rows)
      rows.each_slice(INSERT_BATCH_SIZE) { |batch| model.insert_all!(batch) }
    end
  end
end
