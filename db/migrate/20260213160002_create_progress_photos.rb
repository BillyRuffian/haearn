# Progress photos with date overlay for body tracking
# Uses Active Storage for image attachment
class CreateProgressPhotos < ActiveRecord::Migration[8.1]
  def change
    create_table :progress_photos do |t|
      t.references :user, null: false, foreign_key: true
      t.datetime :taken_at, null: false
      t.string :category # front, back, side_left, side_right, other
      t.text :notes

      t.timestamps
    end

    add_index :progress_photos, [ :user_id, :taken_at ]
    add_index :progress_photos, [ :user_id, :category ]
  end
end
