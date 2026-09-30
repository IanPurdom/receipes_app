class Receipe < ApplicationRecord

  has_many :lists, dependent: :destroy
  has_many :ingredients, through: :lists
  validates :title, presence: true

end