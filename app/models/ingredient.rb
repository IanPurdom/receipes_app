class Ingredient < ApplicationRecord

  has_many :lists, dependent: :destroy
  has_many :receipes, through: :lists
  validates :name, presence: true

end