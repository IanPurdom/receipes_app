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

  describe "GET /receipes (JSON API)" do
    context "when ingredients[] is missing" do
      it "returns a 422 with an error message" do
        get "/receipes", as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)).to eq("error" => "The ingredients[], max_total_time or min_rating parameter is required")
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
      expect(response.body).to include("Search receipes by ingredients")
      expect(response.body).to include("Enter one or more ingredients")
    end

    it "renders the matching receipes when ingredients are given (comma-separated)" do
      get "/receipes", params: { ingredients: "Tomato, Garlic" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(receipe_with_both.title)
      expect(response.body).not_to include(receipe_with_tomato_only.title)
    end

    it "displays the quantity and unit for each ingredient" do
      get "/receipes", params: { ingredients: "Tomato, Garlic" }

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
      get "/receipes", params: { ingredients: "Tomato, Garlic" }

      expect(response.body).to include("Total: 30 min")
    end
  end
end
