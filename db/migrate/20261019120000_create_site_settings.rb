class CreateSiteSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :site_settings do |t|
      t.boolean :registrations_enabled, null: false, default: true
      t.timestamps

      t.check_constraint 'id = 1', name: 'site_settings_singleton'
    end
  end
end
