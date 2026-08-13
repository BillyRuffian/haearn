class AddClientRequestIdToExerciseSets < ActiveRecord::Migration[8.0]
  def change
    add_column :exercise_sets, :client_request_id, :string
    add_index :exercise_sets, :client_request_id, unique: true
  end
end
