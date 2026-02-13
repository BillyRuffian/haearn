class AddFormCuesToExercises < ActiveRecord::Migration[8.0]
  def change
    add_column :exercises, :form_cues, :text
  end
end
