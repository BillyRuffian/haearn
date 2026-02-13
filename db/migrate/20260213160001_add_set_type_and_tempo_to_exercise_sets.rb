# Add set_type enum and tempo fields to exercise_sets
# set_type supports: normal, drop_set, rest_pause, cluster, myo_rep, backoff
# tempo stores eccentric/pause/concentric/pause as individual integer fields
class AddSetTypeAndTempoToExerciseSets < ActiveRecord::Migration[8.1]
  def change
    add_column :exercise_sets, :set_type, :string, default: 'normal'
    add_column :exercise_sets, :tempo_eccentric, :integer
    add_column :exercise_sets, :tempo_pause_bottom, :integer
    add_column :exercise_sets, :tempo_concentric, :integer
    add_column :exercise_sets, :tempo_pause_top, :integer
  end
end
