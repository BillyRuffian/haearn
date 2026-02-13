class AddEquipmentAndOutcomesToExerciseSets < ActiveRecord::Migration[8.0]
  def change
    # Equipment modifiers - track what gear was used per set
    add_column :exercise_sets, :belt, :boolean, default: false, null: false
    add_column :exercise_sets, :knee_sleeves, :boolean, default: false, null: false
    add_column :exercise_sets, :wrist_wraps, :boolean, default: false, null: false
    add_column :exercise_sets, :straps, :boolean, default: false, null: false

    # Set outcomes - what happened during the set
    add_column :exercise_sets, :is_failed, :boolean, default: false, null: false
    add_column :exercise_sets, :partial_reps, :integer
    add_column :exercise_sets, :spotter_assisted, :boolean, default: false, null: false
    add_column :exercise_sets, :pain_flag, :boolean, default: false, null: false
    add_column :exercise_sets, :pain_note, :string

    # Advanced loading - accommodating resistance
    add_column :exercise_sets, :band_tension_kg, :decimal
    add_column :exercise_sets, :chain_weight_kg, :decimal
    add_column :exercise_sets, :is_bfr, :boolean, default: false, null: false
  end
end
