class CreateWorkoutTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :workout_templates do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name
      t.text :description

      t.timestamps
    end
  end
end
