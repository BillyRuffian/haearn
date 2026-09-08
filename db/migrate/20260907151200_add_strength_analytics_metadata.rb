# frozen_string_literal: true

class AddStrengthAnalyticsMetadata < ActiveRecord::Migration[8.1]
  def up
    add_column :exercises, :strength_lift_key, :string
    add_index :exercises, :strength_lift_key
    add_column :users, :strength_scoring_sex, :string

    execute <<~SQL.squish
      UPDATE exercises
      SET strength_lift_key = CASE name
        WHEN 'Back Squat' THEN 'squat'
        WHEN 'Bench Press' THEN 'bench'
        WHEN 'Conventional Deadlift' THEN 'deadlift'
        WHEN 'Overhead Press' THEN 'overhead_press'
      END
      WHERE user_id IS NULL
    SQL
  end

  def down
    remove_column :users, :strength_scoring_sex
    remove_index :exercises, :strength_lift_key
    remove_column :exercises, :strength_lift_key
  end
end
