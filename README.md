# Receipes

A small Ruby on Rails app to search recipes by ingredients, preparation/cooking
time and rating. It ships with a dataset of several hundred recipes (seeded
automatically on first boot) and exposes both an HTML search page and a JSON
API.

## Features

- **Search by ingredients**, matching either **all** of them or **any** of
  them, case-insensitive.
- **Ingredient autocomplete**: type an ingredient, pick a suggestion and it is
  added as a removable tag below the search bar (Backspace on an empty field
  removes the last tag).
- **Filter by max total time** (prep + cook time combined, in minutes).
- **Filter by min rating** (0 to 5).
- All filters can be combined, and each one is optional (at least one must be
  provided).
- Results show the recipe's title, cuisine, category, author, prep/cook/total
  time, rating, image (with a default placeholder when none is provided) and
  the full ingredient list with quantities.

## User stories

- **As a user**, I want to search for recipes by giving a list of ingredients
  I have, so that I can find recipes I can cook with them.
- **As a user**, I want to choose whether a recipe must contain *all* the
  ingredients I entered or *at least one* of them, so that I can broaden or
  narrow my search.
- **As a user**, I want to filter recipes by a maximum total time (prep +
  cook time combined), so that I can find recipes that fit the time I have
  available.
- **As a user**, I want to filter recipes by a minimum rating, so that I can
  find recipes that other people have found good.
- **As a user**, I want to combine ingredient, time and rating filters
  together, so that I can narrow down my search with several criteria at
  once.

## Requirements

- Ruby `3.3.1` (see `.ruby-version`)
- PostgreSQL `9.5+`
- Bundler (`gem install bundler`)

## Getting started (local development)

```bash
# Install dependencies
bundle install

# Create and migrate the database
bin/rails db:prepare
```

This app uses PostgreSQL (see `config/database.yml`). Make sure a local
PostgreSQL server is running and reachable with the credentials configured
there (by default it connects without a username/password on macOS/Linux,
using your system user).

The first time the database is created, `db/seeds.rb` automatically
downloads and imports the recipe dataset (a few hundred recipes) from a
public S3 bucket. This can take a few minutes.

Start the server:

```bash
bin/rails server
```

Then open http://localhost:3000/receipes in your browser.

## Running the test suite

The app uses RSpec. Run the full suite with:

```bash
bundle exec rspec
```

## Comparing importer performance

To compare the record-by-record importer with the batched importer, run:

```bash
bin/rails importer:benchmark
```

The benchmark uses the first 500 recipes in `receipes.json` by default and
rolls back both runs, so it does not leave imported rows in the database.
Set `LIMIT=10013` to benchmark the complete dataset, or set `DATA=/path/to/file.json`
to use another JSON dataset. Run it only in development or test; the task
refuses to run in production.

## Usage

### HTML search page

Visit `/receipes` and fill in any combination of:

- **Ingredients**: type and pick suggestions one by one; each becomes a tag
- **Match mode**: contains *all* the ingredients (default) or *at least one*
- **Max total time**: prep + cook time, in minutes
- **Min rating**: from 0 to 5

## Deployment

This app is set up to be deployed to [Render](https://render.com) using the
[`render.yaml`](render.yaml) Blueprint:

1. Push this repository to GitHub.
2. In the [Render Dashboard](https://dashboard.render.com), click **New +**
   → **Blueprint** and select this repository. Render will detect
   `render.yaml` and provision a free PostgreSQL database and a free Docker
   web service.
3. When prompted, enter the `RAILS_MASTER_KEY` environment variable using the
   value from your local `config/master.key` file (never commit this file).
4. Apply the Blueprint. Render builds the Docker image and starts the
   container. On first boot, `bin/docker-entrypoint` creates/migrates the
   database and seeds it with the recipe dataset in the background, so the
   app can report healthy (`/up`) quickly without hitting Render's health
   check timeout.
5. Once live, visit `https://<your-service>.onrender.com/receipes`.

Note: Render's free web service tier spins down after inactivity and takes
about a minute to wake back up on the next request.
