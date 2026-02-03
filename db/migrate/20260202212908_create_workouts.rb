class CreateWorkouts < ActiveRecord::Migration[8.1]
  def change
    create_table :workouts do |t|
      t.references :user, null: false, foreign_key: true
      t.references :gym, null: false, foreign_key: true
      t.datetime :started_at
      t.datetime :finished_at
      t.text :notes

      t.timestamps
    end
  end
end
