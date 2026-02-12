class CreateAdminAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :admin_audit_logs do |t|
      t.references :admin_user, null: false, foreign_key: { to_table: :users }
      t.references :target_user, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.string :resource_type
      t.integer :resource_id
      t.text :metadata
      t.string :ip_address

      t.timestamps
    end

    add_index :admin_audit_logs, :action
    add_index :admin_audit_logs, :created_at
  end
end
