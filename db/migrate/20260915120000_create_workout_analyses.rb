class CreateWorkoutAnalyses < ActiveRecord::Migration[8.1]
  def change
    create_table :workout_analyses do |t|
      t.references :workout, null: false, foreign_key: true
      t.string :status, null: false, default: 'pending'
      t.string :request_key, null: false
      t.datetime :workout_finished_at, null: false
      t.string :model, null: false
      t.string :prompt_version, null: false
      t.json :input_data
      t.json :response_data
      t.text :summary
      t.string :error_message
      t.string :response_id
      t.json :token_usage
      t.datetime :analysed_at
      t.string :processing_token
      t.timestamps
    end
    add_index :workout_analyses, :request_key, unique: true
    add_index :workout_analyses, [ :workout_id, :id ]
    add_index :workout_analyses, :workout_id, unique: true,
      where: "status IN ('pending', 'processing')", name: 'index_workout_analyses_on_active_workout'
    add_check_constraint :workout_analyses, "status IN ('pending', 'processing', 'completed', 'failed')",
      name: 'workout_analysis_status'
  end
end
