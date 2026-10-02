class List < ApplicationRecord
  belongs_to :receipe
  belongs_to :ingredient

  # Note most used with each ingredient name (keyed by lowercase name). A missing
  # note counts as a candidate too, so rarely used notes are not displayed.
  def self.most_frequent_notes(names)
    return {} if names.empty?

    joins(:ingredient)
      .where("LOWER(ingredients.name) IN (?)", names.map(&:downcase))
      .group(Arel.sql("LOWER(ingredients.name)"), Arel.sql("NULLIF(lists.direction, '')"))
      .count
      .group_by { |(name, _), _| name }
      .transform_values { |rows| rows.max_by { |(_, note), count| [count, note.to_s] }.first.last }
  end
end
