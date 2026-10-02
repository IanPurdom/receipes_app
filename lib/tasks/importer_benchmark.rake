require "benchmark"
require "json"

module ImporterBenchmark
  module_function

  def measure_import
    models = [ Receipe, Ingredient, List ]
    before = models.map(&:count)
    sql_statements = 0
    rows = nil
    subscriber = lambda do |_name, _start, _finish, _id, payload|
      sql_statements += 1 unless payload[:name] == "SCHEMA" || payload[:cached]
    end

    seconds = Benchmark.realtime do
      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
        ActiveRecord::Base.connection.clear_query_cache
        ActiveRecord::Base.transaction do
          yield
          rows = models.map(&:count).zip(before).map { |after, initial| after - initial }
          raise ActiveRecord::Rollback
        end
      end
    end

    { seconds: seconds, sql_statements: sql_statements, rows: rows }
  end

  def import_record_by_record(recipes)
    recipes.each do |input|
      ActiveRecord::Base.transaction do
        receipe = Importer::Receipe.new(input).create
        next unless receipe

        Array(input["ingredients"]).each do |description|
          ingredient = Importer::Ingredient.new(
            ingredient_list: description,
            receipe: receipe
          ).create
          next unless ingredient

          list = Importer::List.new(
            ingredient: ingredient,
            receipe: receipe,
            ingredient_list: description
          ).create

          raise ActiveRecord::Rollback unless list
        end
      end
    end
  end
end

namespace :importer do
  desc "Compare record-by-record and batched imports without keeping imported data"
  task benchmark: :environment do
    abort "Run this benchmark only in development or test." if Rails.env.production?

    data_path = ENV.fetch("DATA", Rails.root.join("receipes.json").to_s)
    abort "Dataset not found at #{data_path.inspect}; set DATA to a JSON dataset." unless File.file?(data_path)

    recipes = JSON.parse(File.read(data_path))
    limit = Integer(ENV.fetch("LIMIT", "500"), 10)
    abort "LIMIT must be a positive integer." unless limit.positive?

    recipes = recipes.first(limit)
    abort "No recipes found to benchmark." if recipes.empty?

    puts "Benchmarking #{recipes.length} recipes from #{data_path}"
    puts "Both runs are rolled back; no imported rows will be kept."

    legacy = ImporterBenchmark.measure_import do
      ImporterBenchmark.import_record_by_record(recipes)
    end
    batched = ImporterBenchmark.measure_import do
      Importer::ImporterService.new(recipes).import
    end

    abort "The two import methods produced different row counts: #{legacy[:rows]} vs #{batched[:rows]}." unless legacy[:rows] == batched[:rows]

    puts
    puts format("%-25s %10s %14s", "Method", "Time (s)", "SQL statements")
    puts format("%-25s %10.2f %14d", "Record by record", legacy[:seconds], legacy[:sql_statements])
    puts format("%-25s %10.2f %14d", "Batched", batched[:seconds], batched[:sql_statements])
    puts format("Speedup: %.1fx", legacy[:seconds] / batched[:seconds]) if batched[:seconds].positive?
  end
end
