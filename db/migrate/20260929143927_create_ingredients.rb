class CreateIngredients < ActiveRecord::Migration[8.1]
  def change
    create_table :ingredients do |t|
      t.string :name
      t.string :measure_type

      t.timestamps
    end
  end
end
