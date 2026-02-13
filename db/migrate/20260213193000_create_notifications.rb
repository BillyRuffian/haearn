class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :severity, null: false, default: 'info'
      t.string :title, null: false
      t.text :message, null: false
      t.json :metadata, null: false, default: {}
      t.string :dedupe_key, null: false
      t.datetime :read_at

      t.timestamps
    end

    add_index :notifications, [:user_id, :dedupe_key], unique: true
    add_index :notifications, [:user_id, :read_at]
    add_index :notifications, [:user_id, :created_at]
  end
end
