class ReceipesController < ApplicationController
  PER_PAGE_OPTIONS = [10, 20, 50, 100].freeze
  DEFAULT_PER_PAGE = 20
  SUGGESTION_MIN_RATING = 4.5
  SUGGESTIONS_COUNT = 6
  MIN_RATING_OPTIONS = [4.5, 4, 3, 2, 1].freeze
  MAX_TOTAL_TIME_OPTIONS = [5, 10, 15, 30, 45, 60, 90, 120].freeze
  # NULL only when both times are missing, as in the total_time helper.
  TOTAL_TIME_SQL = "(CASE WHEN receipes.prep_time IS NULL AND receipes.cook_time IS NULL THEN NULL " \
                   "ELSE COALESCE(receipes.prep_time, 0) + COALESCE(receipes.cook_time, 0) END)".freeze
  # Missing values are always listed last; id keeps the order stable across pages.
  SORT_OPTIONS = {
    "default" => ["Default", "receipes.id"],
    "rating_desc" => ["Rating (best first)", "receipes.ratings DESC NULLS LAST, receipes.id"],
    "rating_asc" => ["Rating (lowest first)", "receipes.ratings ASC NULLS LAST, receipes.id"],
    "prep_time_asc" => ["Prep time (shortest first)", "receipes.prep_time ASC NULLS LAST, receipes.id"],
    "prep_time_desc" => ["Prep time (longest first)", "receipes.prep_time DESC NULLS LAST, receipes.id"],
    "cook_time_asc" => ["Cook time (shortest first)", "receipes.cook_time ASC NULLS LAST, receipes.id"],
    "cook_time_desc" => ["Cook time (longest first)", "receipes.cook_time DESC NULLS LAST, receipes.id"],
    "total_time_asc" => ["Total time (shortest first)", "#{TOTAL_TIME_SQL} ASC NULLS LAST, receipes.id"],
    "total_time_desc" => ["Total time (longest first)", "#{TOTAL_TIME_SQL} DESC NULLS LAST, receipes.id"]
  }.freeze

  # GET /receipes?ingredients=Tomato,Garlic&match=all&max_total_time=30&min_rating=4 (HTML form)
  # GET /receipes.json?ingredients[]=Tomato&ingredients[]=Garlic&match=all&max_total_time=30&min_rating=4 (API)
  #
  # Parameters (at least one must be provided):
  #   ingredients (optional)    - ingredient names to search for, either as
  #                                an array (ingredients[]=...) or a
  #                                comma-separated string (ingredients=a,b)
  #   excluded (optional)       - ingredient names to avoid (excluded[]=...);
  #                                receipes containing any of them are hidden
  #   match (optional)          - "all" (default) for receipes containing
  #                                every ingredient, "any" for those
  #                                containing at least one
  #   max_total_time (optional) - maximum total time (prep + cook), in
  #                                minutes
  #   min_rating (optional)     - minimum rating (0-5)
  #   page (optional)           - page number of the HTML results; the JSON
  #                                API is not paginated
  #   sort (optional)           - default, rating_desc, rating_asc,
  #                                prep_time_asc/desc, cook_time_asc/desc or
  #                                total_time_asc/desc (HTML only)
  #   per_page (optional)       - receipes per HTML page: 10, 20 (default),
  #                                50 or 100
  def index
    @per_page = DEFAULT_PER_PAGE
    @sort = SORT_OPTIONS.key?(params[:sort]) ? params[:sort] : "default"
    @match = params[:match] == "any" ? "any" : "all"
    @ingredient_names = parse_ingredient_names(params[:ingredients])
    @ingredient_notes = List.most_frequent_notes(@ingredient_names)
    @excluded_names = parse_ingredient_names(params[:excluded])
    @excluded_notes = List.most_frequent_notes(@excluded_names)
    @max_total_time = parse_max_total_time(params[:max_total_time])
    @min_rating = parse_min_rating(params[:min_rating])

    if @ingredient_names.empty? && @excluded_names.empty? && @max_total_time.nil? && @min_rating.nil?
      @receipes = []
      respond_to do |format|
        format.html { @suggestions = random_suggestions }
        format.json do
          render json: { error: "The ingredients[], excluded[], max_total_time or min_rating parameter is required" },
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

    relation = relation.without_ingredients(@excluded_names) if @excluded_names.any?
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

  # Random top-rated receipes shown when no search criterion is given.
  def random_suggestions
    Receipe.with_min_rating(SUGGESTION_MIN_RATING)
           .reorder(Arel.sql("RANDOM()")).limit(SUGGESTIONS_COUNT)
           .preload(lists: :ingredient).to_a
  end

  # The scopes use GROUP BY / DISTINCT, so paginate on the matching ids.
  def paginate(relation)
    matching = Receipe.where(id: relation.select("receipes.id"))
    @total_count = matching.count
    @per_page = PER_PAGE_OPTIONS.include?(params[:per_page].to_i) ? params[:per_page].to_i : DEFAULT_PER_PAGE
    @total_pages = [(@total_count / @per_page.to_f).ceil, 1].max
    @page = params[:page].to_i.clamp(1, @total_pages)
    @receipes = matching.order(Arel.sql(SORT_OPTIONS.fetch(@sort).last)).offset((@page - 1) * @per_page).limit(@per_page)
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


