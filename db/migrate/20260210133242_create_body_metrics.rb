class CreateBodyMetrics < ActiveRecord::Migration[8.1]
  def change
    create_table :body_metrics do |t|
      t.references :user, null: false, foreign_key: true
      t.datetime :measured_at, null: false
      t.decimal :weight_kg, precision: 5, scale: 2
      t.decimal :chest_cm, precision: 5, scale: 1
      t.decimal :waist_cm, precision: 5, scale: 1
      t.decimal :hips_cm, precision: 5, scale: 1
      t.decimal :left_arm_cm, precision: 5, scale: 1
      t.decimal :right_arm_cm, precision: 5, scale: 1
      t.decimal :left_leg_cm, precision: 5, scale: 1
      t.decimal :right_leg_cm, precision: 5, scale: 1
      t.text :notes

      t.timestamps
    end

    add_index :body_metrics, [ :user_id, :measured_at ]
  end
end
