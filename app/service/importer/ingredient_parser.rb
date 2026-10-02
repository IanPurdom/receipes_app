module Importer
  class IngredientParser
    FRACTIONS = {
      "½" => 1 / 2r,
      "⅓" => 1 / 3r,
      "⅔" => 2 / 3r,
      "¼" => 1 / 4r,
      "¾" => 3 / 4r,
      "⅕" => 1 / 5r,
      "⅖" => 2 / 5r,
      "⅗" => 3 / 5r,
      "⅘" => 4 / 5r,
      "⅙" => 1 / 6r,
      "⅚" => 5 / 6r,
      "⅛" => 1 / 8r,
      "⅜" => 3 / 8r,
      "⅝" => 5 / 8r,
      "⅞" => 7 / 8r,
      "⅐" => 1 / 7r,
      "⅑" => 1 / 9r,
      "⅒" => 1 / 10r
    }.freeze

    UNITS = {
      "can or bottle" => "can",
      "cans or bottles" => "can",
      "fluid ounces" => "fluid ounce",
      "fluid ounce" => "fluid ounce",
      "fl. oz." => "fluid ounce",
      "fl. oz" => "fluid ounce",
      "fl oz." => "fluid ounce",
      "fl oz" => "fluid ounce",
      "tablespoons" => "tablespoon",
      "tablespoon" => "tablespoon",
      "tbsp" => "tablespoon",
      "tbsp." => "tablespoon",
      "teaspoons" => "teaspoon",
      "teaspoon" => "teaspoon",
      "tsp" => "teaspoon",
      "tsp." => "teaspoon",
      "packages" => "package",
      "package" => "package",
      "pkgs" => "package",
      "pkg" => "package",
      "ounces" => "ounce",
      "ounce" => "ounce",
      "oz" => "ounce",
      "pounds" => "pound",
      "pound" => "pound",
      "lbs" => "pound",
      "lb" => "pound",
      "cups" => "cup",
      "cup" => "cup",
      "slices" => "slice",
      "slice" => "slice",
      "cloves" => "clove",
      "clove" => "clove",
      "bunches" => "bunch",
      "bunch" => "bunch",
      "capsules" => "capsule",
      "capsule" => "capsule",
      "pinches" => "pinch",
      "pinch" => "pinch",
      "dashes" => "dash",
      "dash" => "dash",
      "cans" => "can",
      "can" => "can",
      "jars" => "jar",
      "jar" => "jar",
      "bottles" => "bottle",
      "bottle" => "bottle",
      "containers" => "container",
      "container" => "container",
      "sticks" => "stick",
      "stick" => "stick",
      "heads" => "head",
      "head" => "head",
      "stalks" => "stalk",
      "stalk" => "stalk",
      "sprigs" => "sprig",
      "sprig" => "sprig",
      "pieces" => "piece",
      "piece" => "piece"
    }.freeze

    FRACTION_PATTERN = Regexp.union(FRACTIONS.keys)
    NUMBER_PATTERN = "(?:\\d+(?:\\.\\d+)?(?:\\s*(?:\\d+\\/\\d+|#{FRACTION_PATTERN.source}))?|\\d+\\/\\d+|#{FRACTION_PATTERN.source})".freeze
    QUANTITY_PATTERN = /\A(?<quantity>#{NUMBER_PATTERN}(?:\s*(?:-|to)\s*#{NUMBER_PATTERN})?)(?=\s|$)/i
    UNIT_PATTERN = /\A(?<unit>#{UNITS.keys.sort_by { |unit| -unit.length }.map { |unit| Regexp.escape(unit) }.join("|")})(?=\s|$)/i
    PARENTHETICAL_SIZE_PATTERN = /\(\s*\d+(?:\.\d+)?\s*-?\s*(?:fluid\s+ounces?|fl\.?\s*oz\.?|ounces?|oz\.?)\s*\)/i

    DIRECTION_PHRASES = "as needed|to taste|for garnish|for serving|divided|optional|(?:lightly |well )?beaten(?: with)?"
    TRAILING_DIRECTION_PATTERN = /[\s,]*(?:\(\s*(?:or\s+)?(?:#{DIRECTION_PHRASES})\s*\)|(?:or\s+)?(?:#{DIRECTION_PHRASES}))\s*\z/i
    LEADING_DIRECTION_PATTERN = /\A(?:#{DIRECTION_PHRASES})\s+/i

    attr_reader :direction, :measure, :measure_type, :name

    def initialize(ingredient_description)
      description, direction = ingredient_description.to_s.split(",", 2)
      @direction = direction&.strip.presence
      @remaining = description.to_s.strip

      extract_inline_direction
      extract_measure
      extract_measure_type
      extract_leading_direction
      extract_name
    end

    private

    # Handles lines where the note is not separated by a comma ("water as needed").
    def extract_inline_direction
      while (note = @remaining[TRAILING_DIRECTION_PATTERN])
        @remaining = @remaining.delete_suffix(note).strip
        add_direction(note.gsub(/\A[\s,]+|[\s,]+\z/, "").delete_prefix("(").delete_suffix(")").strip)
      end
    end

    def extract_leading_direction
      return unless (note = @remaining[LEADING_DIRECTION_PATTERN])

      @remaining = @remaining.delete_prefix(note).lstrip
      add_direction(note.strip)
    end

    def add_direction(note)
      @direction = [note, @direction].compact.join(", ")
    end

    def extract_measure
      quantity = @remaining.match(QUANTITY_PATTERN)&.[](:quantity)
      @measure = parse_quantity(quantity) if quantity
      @remaining = @remaining.delete_prefix(quantity).lstrip if quantity
    end

    def parse_quantity(quantity)
      # The schema stores one quantity, so use the lower bound for ranges.
      quantity = quantity.split(/\s*(?:-|to)\s*/i, 2).first
      if (match = quantity.match(/\A(?<whole>\d+(?:\.\d+)?)(?<fraction>\s*(?:\d+\/\d+|#{FRACTION_PATTERN}))?\z/))
        whole = match[:whole].to_r
        fraction = match[:fraction]&.strip
        return whole + parse_fraction(fraction) if fraction

        whole
      else
        parse_fraction(quantity)
      end
    end

    def parse_fraction(fraction)
      FRACTIONS[fraction] || fraction.to_r
    end

    def extract_measure_type
      @remaining = @remaining.sub(PARENTHETICAL_SIZE_PATTERN, " ").squeeze(" ").strip
      unit = @remaining.match(UNIT_PATTERN)
      return unless unit

      @measure_type = UNITS.fetch(unit[:unit].downcase)
      @remaining = @remaining.delete_prefix(unit[:unit]).lstrip
    end

    def extract_name
      @name = @remaining.sub(/\Aof\s+/i, "").squeeze(" ").strip.singularize
    end
  end
end
