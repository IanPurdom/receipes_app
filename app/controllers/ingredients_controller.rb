class IngredientsController < ApplicationController
  SUGGESTION_LIMIT = 10
  MIN_QUERY_LENGTH = 2

  def suggestions
    query = params[:q].to_s.strip
    render json: query.length >= MIN_QUERY_LENGTH ? build_suggestions(query.downcase) : []
  end

  private

  def build_suggestions(query)
    names =
      Ingredient
        .where("LEFT(LOWER(name), LENGTH(?)) = ?", query, query)
        .group("LOWER(name)")
        .order(Arel.sql("LOWER(name)"))
        .limit(SUGGESTION_LIMIT)
        .pluck(Arel.sql("MIN(name)"))

    notes = List.most_frequent_notes(names)
    names.map { |name| { name: name, note: notes[name.downcase] } }
  end
end
