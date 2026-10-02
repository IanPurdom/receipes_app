class ReceipesController < ApplicationController
  PER_PAGE_OPTIONS = [10, 20, 50, 100].freeze
  DEFAULT_PER_PAGE = 20

  # GET /receipes?ingredients=Tomato,Garlic&match=all&max_total_time=30&min_rating=4 (HTML form)
  # GET /receipes.json?ingredients[]=Tomato&ingredients[]=Garlic&match=all&max_total_time=30&min_rating=4 (API)
  #
  # Parameters (at least one must be provided):
  #   ingredients (optional)    - ingredient names to search for, either as
  #                                an array (ingredients[]=...) or a
  #                                comma-separated string (ingredients=a,b)
  #   match (optional)          - "all" (default) for receipes containing
  #                                every ingredient, "any" for those
  #                                containing at least one
  #   max_total_time (optional) - maximum total time (prep + cook), in
  #                                minutes
  #   min_rating (optional)     - minimum rating (0-5)
  #   page (optional)           - page number of the HTML results; the JSON
  #                                API is not paginated
  #   per_page (optional)       - receipes per HTML page: 10, 20 (default),
  #                                50 or 100
  def index
    @per_page = DEFAULT_PER_PAGE
    @match = params[:match] == "any" ? "any" : "all"
    @ingredient_names = parse_ingredient_names(params[:ingredients])
    @ingredient_notes = List.most_frequent_notes(@ingredient_names)
    @max_total_time = parse_max_total_time(params[:max_total_time])
    @min_rating = parse_min_rating(params[:min_rating])

    if @ingredient_names.empty? && @max_total_time.nil? && @min_rating.nil?
      @receipes = []
      respond_to do |format|
        format.html
        format.json do
          render json: { error: "The ingredients[], max_total_time or min_rating parameter is required" },
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
    relation = relation.with_min_rating(@min_rating) if @min_rating

    respond_to do |format|
      format.html do
        paginate(relation)
      end
      format.json do
        @receipes = relation.preload(lists: :ingredient).to_a
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

  # The scopes use GROUP BY / DISTINCT, so paginate on the matching ids.
  def paginate(relation)
    matching = Receipe.where(id: relation.select("receipes.id"))
    @total_count = matching.count
    @per_page = PER_PAGE_OPTIONS.include?(params[:per_page].to_i) ? params[:per_page].to_i : DEFAULT_PER_PAGE
    @total_pages = [(@total_count / @per_page.to_f).ceil, 1].max
    @page = params[:page].to_i.clamp(1, @total_pages)
    @receipes = matching.order(:id).offset((@page - 1) * @per_page).limit(@per_page)
                        .preload(lists: :ingredient).to_a
  end

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

  # Converts the parameter to a float within 0..5, or nil if missing/invalid.
  def parse_min_rating(raw)
    return nil if raw.blank?

    rating = raw.to_f
    return nil if rating <= 0 || rating > 5

    rating
  end
end


