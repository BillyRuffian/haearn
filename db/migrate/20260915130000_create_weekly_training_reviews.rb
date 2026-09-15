class CreateWeeklyTrainingReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :weekly_training_reviews do |t|
      t.references :user, null: false, foreign_key: true
      t.date :week_start, null: false
      t.string :status, null: false, default: 'pending'
      t.string :delivery_status, null: false, default: 'pending'
      t.string :model, null: false
      t.string :prompt_version, null: false
      t.json :summary_data
      t.json :input_data
      t.json :response_data
      t.json :token_usage
      t.string :response_id
      t.string :error_message
      t.string :delivery_error
      t.string :processing_token
      t.integer :attempts, null: false, default: 0
      t.datetime :retry_at
      t.datetime :analysed_at
      t.datetime :delivery_started_at
      t.datetime :sent_at
      t.timestamps
    end
    add_index :weekly_training_reviews, [ :user_id, :week_start ], unique: true
    add_index :weekly_training_reviews, [ :delivery_status, :status, :retry_at ], name: 'index_weekly_reviews_on_recovery'
    add_check_constraint :weekly_training_reviews, "status IN ('pending', 'processing', 'completed', 'failed')", name: 'weekly_review_status'
    add_check_constraint :weekly_training_reviews, "delivery_status IN ('pending', 'sending', 'sent', 'uncertain', 'skipped')", name: 'weekly_review_delivery_status'
  end
end
