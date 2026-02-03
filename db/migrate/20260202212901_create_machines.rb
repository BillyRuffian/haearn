class CreateMachines < ActiveRecord::Migration[8.1]
  def change
    create_table :machines do |t|
      t.references :gym, null: false, foreign_key: true
      t.string :name
      t.string :equipment_type
      t.decimal :weight_ratio
      t.string :display_unit
      t.text :notes

      t.timestamps
    end
  end
end
