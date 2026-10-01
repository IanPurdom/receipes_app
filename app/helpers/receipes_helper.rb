require "cgi"

module ReceipesHelper
  # Formats an ingredient's quantity for display, for example:
  #   format_quantity(1, "cup")    => "1 cup"
  #   format_quantity(0.667, "cup") => "0.67 cup"
  #   format_quantity(2, nil)      => "2"
  #   format_quantity(nil, "cup")  => "cup"
  def format_quantity(measure, measure_type)
    parts = []
    parts << format_measure(measure) if measure.present?
    parts << measure_type if measure_type.present?
    parts.join(" ")
  end

  # Total time (prep + cook) of a receipe, in minutes, or nil if neither
  # time is set.
  def total_time(receipe)
    return nil if receipe.prep_time.blank? && receipe.cook_time.blank?

    receipe.prep_time.to_i + receipe.cook_time.to_i
  end

  DEFAULT_IMAGE = "receipe-placeholder.svg".freeze

  # The stored image is a URL to an image proxy
  # (imagesvc.meredithcorp.io/v3/mm/image?url=...) that blocks hotlinked/
  # automated requests. Extract the real underlying image URL (the "url"
  # query parameter) so the image can actually be loaded. Falls back to a
  # default placeholder image when no image is set.
  def receipe_image_url(receipe)
    return image_path(DEFAULT_IMAGE) if receipe.image.blank?

    uri = URI.parse(receipe.image)
    real_url = CGI.parse(uri.query.to_s)["url"]&.first
    real_url.presence || receipe.image
  rescue URI::InvalidURIError
    receipe.image
  end

  private

  # Avoids displaying unnecessary decimals (1.000 -> "1", 0.667 -> "0.67").
  def format_measure(measure)
    rounded = measure.to_f.round(2)
    rounded == rounded.to_i ? rounded.to_i.to_s : rounded.to_s
  end
end
