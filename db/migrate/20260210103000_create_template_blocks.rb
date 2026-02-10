class CreateTemplateBlocks < ActiveRecord::Migration[8.1]
  def change
    create_table :template_blocks do |t|
      t.references :workout_template, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.integer :rest_seconds, default: 90

      t.timestamps
    end

    add_index :template_blocks, [ :workout_template_id, :position ]
  end
end
