class Receipe < ApplicationRecord

  has_many :lists, dependent: :destroy
  has_many :ingredients, through: :lists
  validates :title, presence: true

  # Receipes containing at least one of the given ingredients (by name,
  # case-insensitive).
  scope :with_any_ingredients, lambda { |names|
    names = Array(names).map { |name| name.to_s.downcase }.uniq
    joins(:ingredients).where("LOWER(ingredients.name) IN (?)", names).distinct
  }

  # Receipes containing all of the given ingredients (by name,
  # case-insensitive).
  scope :with_all_ingredients, lambda { |names|
    names = Array(names).map { |name| name.to_s.downcase }.uniq
    joins(:ingredients)
      .where("LOWER(ingredients.name) IN (?)", names)
      .group("receipes.id")
      .having("COUNT(DISTINCT LOWER(ingredients.name)) = ?", names.size)
  }

  # Receipes containing none of the given ingredients (by name,
  # case-insensitive).
  scope :without_ingredients, lambda { |names|
    names = Array(names).map { |name| name.to_s.downcase }.uniq
    where(<<~SQL.squish, names)
      NOT EXISTS (
        SELECT 1 FROM lists
        INNER JOIN ingredients ON ingredients.id = lists.ingredient_id
        WHERE lists.receipe_id = receipes.id AND LOWER(ingredients.name) IN (?)
      )
    SQL
  }

  # Receipes whose total time (prep + cook) does not exceed `minutes`.
  # Missing times (NULL) are treated as 0.
  scope :with_max_total_time, lambda { |minutes|
    where("COALESCE(prep_time, 0) + COALESCE(cook_time, 0) <= ?", minutes)
  }

  # Receipes whose rating is at least `rating`. Receipes without a rating
  # are excluded.
  scope :with_min_rating, lambda { |rating|
    where("ratings >= ?", rating)
  }

end