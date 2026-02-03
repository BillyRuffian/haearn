class CreateGyms < ActiveRecord::Migration[8.1]
  def change
    create_table :gyms do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name
      t.string :location
      t.text :notes

      t.timestamps
    end
  end
end
