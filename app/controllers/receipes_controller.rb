class ReceipesController < ApplicationController
  # GET /receipes?ingredients=Tomato,Garlic&match=all&max_total_time=30 (HTML form)
  # GET /receipes.json?ingredients[]=Tomato&ingredients[]=Garlic&match=all&max_total_time=30 (API)
  #
  # Parameters (at least one of the two must be provided):
  #   ingredients (optional)    - ingredient names to search for, either as
  #                                an array (ingredients[]=...) or a
  #                                comma-separated string (ingredients=a,b)
  #   match (optional)          - "all" (default) for receipes containing
  #                                every ingredient, "any" for those
  #                                containing at least one
  #   max_total_time (optional) - maximum total time (prep + cook), in
  #                                minutes
  def index
    @match = params[:match] == "any" ? "any" : "all"
    @ingredient_names = parse_ingredient_names(params[:ingredients])
    @max_total_time = parse_max_total_time(params[:max_total_time])

    if @ingredient_names.empty? && @max_total_time.nil?
      @receipes = []
      respond_to do |format|
        format.html
        format.json do
          render json: { error: "The ingredients[] or max_total_time parameter is required" },
                 status: :unprocessable_content
        end
      end
      return
    end

    relation =
      if @ingredient_names.any?
        @match == "any" ? Receipe.with_any_ingredients(@ingredient_names) : Receipe.with_all_ingredients(@ingredient_names)
      else
        Receipe.all
      end

    relation = relation.with_max_total_time(@max_total_time) if @max_total_time

    @receipes = relation.preload(lists: :ingredient).to_a

    respond_to do |format|
      format.html
      format.json do
        render json: @receipes.as_json(
          only: %i[id title cook_time prep_time ratings cuisine category author image],
          include: {
            lists: {
              only: %i[measure direction],
              include: { ingredient: { only: %i[id name measure_type] } }
            }
          }
        )
      end
    end
  end

  private

  # Accepts either an array (API: ingredients[]=a&ingredients[]=b) or a
  # comma-separated string (form: ingredients=a,b).
  def parse_ingredient_names(raw)
    names = raw.is_a?(String) ? raw.split(",") : Array(raw)
    names.map { |name| name.to_s.strip }.reject(&:blank?)
  end

  # Converts the parameter to a positive integer, or nil if missing/invalid.
  def parse_max_total_time(raw)
    return nil if raw.blank?

    minutes = raw.to_i
    minutes.positive? ? minutes : nil
  end
end


