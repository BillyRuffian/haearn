class CreateExercises < ActiveRecord::Migration[8.1]
  def change
    create_table :exercises do |t|
      t.string :name
      t.string :exercise_type
      t.boolean :has_weight
      t.references :user, null: false, foreign_key: true
      t.text :description

      t.timestamps
    end
  end
end
