class ChangeUserIdNullableInExercises < ActiveRecord::Migration[8.1]
  def change
    change_column_null :exercises, :user_id, true
  end
end
