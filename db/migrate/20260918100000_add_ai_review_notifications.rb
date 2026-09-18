class AddAiReviewNotifications < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :notify_ai_analysis_push, :boolean, default: true, null: false
    add_reference :notifications, :workout_analysis, foreign_key: true, index: { unique: true }
    add_column :notifications, :push_processed_at, :datetime
    add_index :notifications, [ :kind, :push_processed_at ]

    create_table :app_presences do |t|
      t.references :session, null: false, foreign_key: true
      t.string :client_id, null: false
      t.integer :sequence, null: false, default: 0
      t.datetime :expires_at, null: false
    end
    add_index :app_presences, [ :session_id, :client_id ], unique: true
    add_index :app_presences, :expires_at
  end
end
