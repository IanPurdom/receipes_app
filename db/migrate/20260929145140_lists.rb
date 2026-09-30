class Lists < ActiveRecord::Migration[8.1]
  def change
    create_table :lists do |t|
      t.references :receipe, null: false, foreign_key: true
      t.references :ingredient, null: false, foreign_key: true
      t.decimal :measure, precision: 8, scale: 3
      t.string :direction
    end
  end
end
