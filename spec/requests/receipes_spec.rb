require "rails_helper"

RSpec.describe "Receipes", type: :request do
  let!(:tomato) { create(:ingredient, name: "Tomato") }
  let!(:garlic) { create(:ingredient, name: "Garlic") }
  let!(:basil) { create(:ingredient, name: "Basil") }

  let!(:receipe_with_both) { create(:receipe, title: "Tomato and garlic sauce", prep_time: 10, cook_time: 20, ratings: 4.5) }
  let!(:receipe_with_tomato_only) { create(:receipe, title: "Tomato soup", prep_time: 20, cook_time: 40, ratings: 3.0) }
  let!(:receipe_without_ingredients) { create(:receipe, title: "Plain water", prep_time: 1, cook_time: 0, ratings: nil) }

  before do
    create(:list, receipe: receipe_with_both, ingredient: tomato, measure: 2, direction: "diced")
    create(:list, receipe: receipe_with_both, ingredient: garlic, measure: 3)
    create(:list, receipe: receipe_with_tomato_only, ingredient: tomato, measure: 1)
  end

  describe "GET /ingredients/suggestions" do
    it "returns case-insensitive prefix matches as JSON" do
      get "/ingredients/suggestions", params: { q: "gar" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([{ "name" => "Garlic", "note" => "Mix well" }])
    end

    it "returns distinct names in alphabetical order with a limit" do
      12.times { |index| create(:ingredient, name: "Tomato #{index.to_s.rjust(2, '0')}") }

      get "/ingredients/suggestions", params: { q: "tom" }

      names = response.parsed_body.map { |suggestion| suggestion["name"] }
      expect(names.size).to eq(10)
      expect(names).to eq(names.sort_by(&:downcase))
      expect(names.uniq).to eq(names)
    end

    it "returns the most frequent note used with the ingredient" do
      water = create(:ingredient, name: "Water")
      3.times { create(:list, ingredient: water, direction: "as needed") }
      create(:list, ingredient: water, direction: "cold")

      get "/ingredients/suggestions", params: { q: "wat" }

      expect(response.parsed_body).to eq([{ "name" => "Water", "note" => "as needed" }])
    end

    it "returns no note when most lines have none" do
      salt = create(:ingredient, name: "Salt")
      3.times { create(:list, ingredient: salt, direction: nil) }
      create(:list, ingredient: salt, direction: "to taste")

      get "/ingredients/suggestions", params: { q: "sal" }

      expect(response.parsed_body).to eq([{ "name" => "Salt", "note" => nil }])
    end

    it "does not treat SQL LIKE wildcards in the query as wildcards" do
      create(:ingredient, name: "Wild%card sauce")

      get "/ingredients/suggestions", params: { q: "wild%" }

      expect(response.parsed_body.map { |s| s["name"] }).to eq(["Wild%card sauce"])
    end

    it "returns no results for a query shorter than two characters" do
      get "/ingredients/suggestions", params: { q: "t" }

      expect(response.parsed_body).to eq([])
    end
  end

  describe "GET /receipes (JSON API)" do
    context "when ingredients[] is missing" do
      it "returns a 422 with an error message" do
        get "/receipes", as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)).to eq("error" => "The ingredients[], excluded[], max_total_time or min_rating parameter is required")
      end
    end

    context "when ingredients[] is empty" do
      it "returns a 422 with an error message" do
        get "/receipes", params: { ingredients: [""] }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "without the match param (defaults to all)" do
      it "returns only receipes containing every given ingredient" do
        get "/receipes", params: { ingredients: %w[Tomato Garlic] }, as: :json

        expect(response).to have_http_status(:ok)
        titles = JSON.parse(response.body).map { |r| r["title"] }
        expect(titles).to contain_exactly(receipe_with_both.title)
      end
    end

    context "with match=all" do
      it "returns only receipes containing every given ingredient" do
        get "/receipes", params: { ingredients: %w[Tomato Garlic], match: "all" }, as: :json

        expect(response).to have_http_status(:ok)
        titles = JSON.parse(response.body).map { |r| r["title"] }
        expect(titles).to contain_exactly(receipe_with_both.title)
      end
    end

    context "with match=any" do
      it "returns receipes containing at least one given ingredient" do
        get "/receipes", params: { ingredients: %w[Garlic Basil], match: "any" }, as: :json

        expect(response).to have_http_status(:ok)
        titles = JSON.parse(response.body).map { |r| r["title"] }
        expect(titles).to contain_exactly(receipe_with_both.title)
      end
    end

    context "with excluded ingredients" do
      def titles
        JSON.parse(response.body).map { |r| r["title"] }
      end

      it "hides the receipes containing an excluded ingredient" do
        get "/receipes", params: { ingredients: ["Tomato"], excluded: ["Garlic"] }, as: :json

        expect(titles).to contain_exactly(receipe_with_tomato_only.title)
      end

      it "works on its own, ignoring the case of the name" do
        get "/receipes", params: { excluded: ["tomato"] }, as: :json

        expect(response).to have_http_status(:ok)
        expect(titles).to contain_exactly(receipe_without_ingredients.title)
      end

      it "hides receipes containing any of several excluded ingredients" do
        get "/receipes", params: { excluded: %w[Garlic Basil] }, as: :json

        expect(titles).to contain_exactly(receipe_with_tomato_only.title, receipe_without_ingredients.title)
      end
    end

    it "includes the receipe's ingredients and their quantities in the JSON payload" do
      get "/receipes", params: { ingredients: ["Tomato"], match: "any" }, as: :json

      payload = JSON.parse(response.body)
      receipe_json = payload.find { |r| r["title"] == receipe_with_both.title }
      tomato_list = receipe_json["lists"].find { |l| l["ingredient"]["name"] == "Tomato" }

      expect(receipe_json["lists"].map { |l| l["ingredient"]["name"] }).to include("Tomato", "Garlic")
      expect(tomato_list["measure"].to_f).to eq(2.0)
      expect(tomato_list["direction"]).to eq("diced")
      expect(tomato_list["ingredient"]["measure_type"]).to eq("cup")
    end

    it "returns an empty array when no receipe matches" do
      get "/receipes", params: { ingredients: ["Unknown"], match: "any" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq([])
    end

    it "also accepts a comma-separated string of ingredients" do
      get "/receipes", params: { ingredients: "Tomato,Garlic" }, as: :json

      expect(response).to have_http_status(:ok)
      titles = JSON.parse(response.body).map { |r| r["title"] }
      expect(titles).to contain_exactly(receipe_with_both.title)
    end

    context "with max_total_time only (no ingredients)" do
      it "returns every receipe whose combined prep + cook time is within the limit" do
        get "/receipes", params: { max_total_time: 30 }, as: :json

        expect(response).to have_http_status(:ok)
        titles = JSON.parse(response.body).map { |r| r["title"] }
        expect(titles).to contain_exactly(receipe_with_both.title, receipe_without_ingredients.title)
      end
    end

    context "with ingredients and max_total_time combined" do
      it "returns only receipes matching both criteria" do
        get "/receipes", params: { ingredients: ["Tomato"], match: "any", max_total_time: 30 }, as: :json

        expect(response).to have_http_status(:ok)
        titles = JSON.parse(response.body).map { |r| r["title"] }
        expect(titles).to contain_exactly(receipe_with_both.title)
      end
    end

    context "with an invalid max_total_time (non-numeric or negative)" do
      it "ignores it and falls back to the ingredients-only search" do
        get "/receipes", params: { ingredients: ["Tomato"], match: "any", max_total_time: "-5" }, as: :json

        expect(response).to have_http_status(:ok)
        titles = JSON.parse(response.body).map { |r| r["title"] }
        expect(titles).to contain_exactly(receipe_with_both.title, receipe_with_tomato_only.title)
      end
    end

    context "with min_rating only (no ingredients)" do
      it "returns every receipe whose rating is at least the given value" do
        get "/receipes", params: { min_rating: 4 }, as: :json

        expect(response).to have_http_status(:ok)
        titles = JSON.parse(response.body).map { |r| r["title"] }
        expect(titles).to contain_exactly(receipe_with_both.title)
      end
    end

    context "with ingredients and min_rating combined" do
      it "returns only receipes matching both criteria" do
        get "/receipes", params: { ingredients: %w[Tomato Garlic], min_rating: 4 }, as: :json

        expect(response).to have_http_status(:ok)
        titles = JSON.parse(response.body).map { |r| r["title"] }
        expect(titles).to contain_exactly(receipe_with_both.title)
      end
    end

    context "with an invalid min_rating (out of the 0-5 range)" do
      it "ignores it and falls back to the ingredients-only search" do
        get "/receipes", params: { ingredients: ["Tomato"], match: "any", min_rating: "10" }, as: :json

        expect(response).to have_http_status(:ok)
        titles = JSON.parse(response.body).map { |r| r["title"] }
        expect(titles).to contain_exactly(receipe_with_both.title, receipe_with_tomato_only.title)
      end
    end
  end

  describe "GET /receipes (HTML view)" do
    it "renders the search form without results when no criteria is given" do
      get "/receipes"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("What would you like to cook today?")
      expect(response.body).to include("Enter one or more ingredients")
    end

    it "suggests only receipes rated 4.5 or more when no criteria is given" do
      get "/receipes"

      expect(response.body).to include("Tomato and garlic sauce")
      expect(response.body).not_to include("Tomato soup")
      expect(response.body).not_to include("Plain water")
    end

    it "does not show suggestions once a criterion is given" do
      get "/receipes", params: { ingredients: %w[Tomato], max_total_time: 120 }

      expect(response.body).not_to include("Need inspiration")
    end

    it "limits suggestions to 6" do
      create_list(:receipe, 8, ratings: 5)
      get "/receipes"

      expect(response.body.scan('class="receipe-card"').size).to eq(6)
    end

    it "renders each selected ingredient as a removable tag with a hidden field" do
      get "/receipes", params: { ingredients: %w[Tomato Garlic] }

      expect(response.body.scan(/<li class="tag">/).size).to eq(2)
      expect(response.body).to include('name="ingredients[]" value="Tomato"')
      expect(response.body).to include('name="ingredients[]" value="Garlic"')
      expect(response.body).to include('aria-label="Remove Tomato"')
    end

    it "renders the matching receipes when ingredients are given" do
      get "/receipes", params: { ingredients: %w[Tomato Garlic] }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(receipe_with_both.title)
      expect(response.body).not_to include(receipe_with_tomato_only.title)
    end

    it "displays the quantity and unit for each ingredient" do
      get "/receipes", params: { ingredients: %w[Tomato Garlic] }

      expect(response.body).to include("2 cup")
      expect(response.body).to include("diced")
      expect(response.body).to include("3 cup")
    end

    it "renders a message when no receipe matches" do
      get "/receipes", params: { ingredients: "Unknown" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No receipe matches")
    end

    it "allows searching by max_total_time alone, without any ingredient" do
      get "/receipes", params: { max_total_time: 30 }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(receipe_with_both.title)
      expect(response.body).to include(receipe_without_ingredients.title)
      expect(response.body).not_to include(receipe_with_tomato_only.title)
    end

    it "renders the excluded ingredients as tags and filters the receipes" do
      get "/receipes", params: { ingredients: ["Tomato"], excluded: ["Garlic"] }

      expect(response.body).to include('name="excluded[]" value="Garlic"')
      expect(response.body).to include("Tomato soup")
      expect(response.body).not_to include("Tomato and garlic sauce")
    end

    it "mentions the excluded ingredients when nothing matches" do
      get "/receipes", params: { ingredients: ["Basil"], excluded: ["Garlic"] }

      expect(response.body).to include("without:")
    end

    it "offers time brackets and selects the current one" do
      get "/receipes", params: { max_total_time: 30 }

      expect(response.body).to include('<option value="5">Less than 5 min</option>')
      expect(response.body).to include('<option selected="selected" value="30">Less than 30 min</option>')
    end

    it "keeps a custom max_total_time from the URL selectable" do
      get "/receipes", params: { max_total_time: 25 }

      expect(response.body).to include('<option selected="selected" value="25">Less than 25 min</option>')
    end

    it "offers rating floors and selects the current one" do
      get "/receipes", params: { min_rating: 4 }

      expect(response.body).to include('<option value="4.5">More than 4.5 rating</option>')
      expect(response.body).to include('<option selected="selected" value="4">More than 4 rating</option>')
    end

    it "combines the ingredients and max_total_time filters" do
      get "/receipes", params: { ingredients: "Tomato", match: "any", max_total_time: 30 }

      expect(response.body).to include(receipe_with_both.title)
      expect(response.body).not_to include(receipe_with_tomato_only.title)
    end

    it "allows searching by min_rating alone, without any ingredient" do
      get "/receipes", params: { min_rating: 4 }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(receipe_with_both.title)
      expect(response.body).not_to include(receipe_with_tomato_only.title)
    end

    it "combines the ingredients and min_rating filters" do
      get "/receipes", params: { ingredients: "Tomato, Garlic", min_rating: 4 }

      expect(response.body).to include(receipe_with_both.title)
      expect(response.body).not_to include(receipe_with_tomato_only.title)
    end

    it "displays the combined total time of each receipe" do
      get "/receipes", params: { ingredients: %w[Tomato Garlic] }

      expect(response.body).to include("Total: 30 min")
    end

    describe "pagination" do
      before do
        garlic = create(:ingredient, name: "Paprika")
        create_list(:receipe, 25).each { |receipe| create(:list, receipe: receipe, ingredient: garlic) }
      end

      it "shows the first 20 receipes and a link to the next page" do
        get "/receipes", params: { ingredients: ["Paprika"] }

        expect(response.body.scan('class="receipe-card"').size).to eq(20)
        expect(response.body).to include("25 receipes found")
        expect(response.body).to include("Page 1 / 2")
        expect(response.body).to include("page=2")
      end

      it "shows the remaining receipes on the last page" do
        get "/receipes", params: { ingredients: ["Paprika"], page: 2 }

        expect(response.body.scan('class="receipe-card"').size).to eq(5)
        expect(response.body).to include("Previous")
        expect(response.body).not_to include("Next")
      end

      it "clamps an out-of-range page" do
        get "/receipes", params: { ingredients: ["Paprika"], page: 99 }

        expect(response.body).to include("Page 2 / 2")
      end

      it "honours the per_page parameter and keeps it in the links" do
        get "/receipes", params: { ingredients: ["Paprika"], per_page: 10 }

        expect(response.body.scan('class="receipe-card"').size).to eq(10)
        expect(response.body).to include("Page 1 / 3")
        expect(response.body).to include("per_page=10")
        expect(response.body).to match(/<option selected="selected" value="10">10<\/option>/)
      end

      it "falls back to 20 for an unsupported per_page" do
        get "/receipes", params: { ingredients: ["Paprika"], per_page: 7 }

        expect(response.body.scan('class="receipe-card"').size).to eq(20)
      end

      it "sorts by rating, best first, and keeps the sort in the links" do
        create(:list, receipe: create(:receipe, title: "Top rated", ratings: 4.99), ingredient: Ingredient.find_by!(name: "Paprika"))
        create(:list, receipe: create(:receipe, title: "Unrated", ratings: nil), ingredient: Ingredient.find_by!(name: "Paprika"))

        get "/receipes", params: { ingredients: ["Paprika"], sort: "rating_desc", per_page: 10 }

        expect(response.body.index("Top rated")).to be < response.body.index("Receipe ")
        expect(response.body).to include("sort=rating_desc")

        get "/receipes", params: { ingredients: ["Paprika"], sort: "rating_desc", per_page: 100 }
        expect(response.body.index("Unrated")).to be > response.body.rindex("Receipe ")
      end

      it "sorts by prep time, shortest first" do
        create(:list, receipe: create(:receipe, title: "Quick one", prep_time: 1), ingredient: Ingredient.find_by!(name: "Paprika"))

        get "/receipes", params: { ingredients: ["Paprika"], sort: "prep_time_asc" }

        expect(response.body.index("Quick one")).to be < response.body.index("Receipe ")
      end

      it "sorts by cook time and by total time" do
        paprika = Ingredient.find_by!(name: "Paprika")
        create(:list, receipe: create(:receipe, title: "Short cook", prep_time: 60, cook_time: 1), ingredient: paprika)
        create(:list, receipe: create(:receipe, title: "Short total", prep_time: 1, cook_time: 2), ingredient: paprika)

        get "/receipes", params: { ingredients: ["Paprika"], sort: "cook_time_asc", per_page: 100 }
        expect(response.body.index("Short cook")).to be < response.body.index("Short total")

        get "/receipes", params: { ingredients: ["Paprika"], sort: "total_time_asc", per_page: 100 }
        expect(response.body.index("Short total")).to be < response.body.index("Short cook")

        get "/receipes", params: { ingredients: ["Paprika"], sort: "total_time_desc", per_page: 100 }
        expect(response.body.index("Short cook")).to be < response.body.index("Short total")
      end

      it "ignores an unknown sort" do
        get "/receipes", params: { ingredients: ["Paprika"], sort: "title; DROP TABLE" }

        expect(response).to have_http_status(:ok)
        expect(response.body.scan('class="receipe-card"').size).to eq(20)
      end

      it "does not paginate the JSON API" do
        get "/receipes", params: { ingredients: ["Paprika"] }, as: :json

        expect(response.parsed_body.size).to eq(25)
      end
    end
  end
end
