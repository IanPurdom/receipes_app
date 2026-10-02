module Importer
  class Receipe
    attr_reader :receipe_list

    def initialize(receipe_list)
      @receipe_list = receipe_list
    end

    def create
      receipe = ::Receipe.new(title: receipe_list["title"],
                            cook_time: receipe_list["cook_time"],
                            prep_time: receipe_list["prep_time"],
                            ratings: receipe_list["ratings"],
                            cuisine: receipe_list["cuisine"],
                            category: receipe_list["category"],
                             author: receipe_list["author"],
                            image: receipe_list["image"])

      if receipe.save
        receipe
      else
        Rails.logger.warn "Could not import receipe #{receipe.title.inspect}: #{receipe.errors.full_messages.join(', ')}"
        false
      end
    end
  end
end
