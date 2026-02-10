class AddWeeklySummaryEmailToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :weekly_summary_email, :boolean, default: false, null: false
  end
end
