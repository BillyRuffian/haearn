class CreateTrainingProgramsAndSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :training_programs do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.integer :weeks_count, null: false, default: 4
      t.datetime :archived_at

      t.timestamps
    end

    add_index :training_programs, [ :user_id, :archived_at ]

    create_table :program_sessions do |t|
      t.references :training_program, null: false, foreign_key: true
      t.references :workout_template, null: false, foreign_key: true
      t.string :name
      t.text :notes
      t.integer :week_number, null: false
      t.integer :weekday, null: false
      t.integer :position, null: false, default: 1
      t.integer :volume_percent, null: false, default: 100
      t.integer :intensity_percent, null: false, default: 100

      t.timestamps
    end

    add_index :program_sessions,
      [ :training_program_id, :week_number, :weekday, :position ],
      unique: true,
      name: :index_program_sessions_on_schedule

    create_table :program_cycles do |t|
      t.references :training_program, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.date :starts_on, null: false
      t.date :ended_on
      t.string :status, null: false, default: 'active'

      t.timestamps
    end

    add_index :program_cycles, [ :training_program_id, :status ]
    add_index :program_cycles,
      :user_id,
      unique: true,
      where: "status = 'active'",
      name: :index_program_cycles_on_one_active_user

    create_table :program_session_executions do |t|
      t.references :program_cycle, null: false, foreign_key: true
      t.references :program_session, null: false, foreign_key: true
      t.date :scheduled_on, null: false
      t.string :status, null: false, default: 'planned'
      t.string :skip_reason
      t.text :skip_notes
      t.string :adjustment_reason
      t.text :adjustment_notes
      t.integer :volume_percent, null: false, default: 100
      t.integer :intensity_percent, null: false, default: 100
      t.integer :prescribed_sets, null: false, default: 0
      t.decimal :prescribed_volume_kg, precision: 12, scale: 3, null: false, default: 0
      t.json :prescription, null: false, default: []
      t.string :session_name, null: false
      t.string :workout_template_name, null: false
      t.datetime :completed_at

      t.timestamps
    end

    add_index :program_session_executions,
      [ :program_cycle_id, :program_session_id ],
      unique: true,
      name: :index_program_executions_on_cycle_and_session
    add_index :program_session_executions, [ :program_cycle_id, :scheduled_on ]

    add_reference :workouts,
      :program_session_execution,
      foreign_key: true,
      index: { unique: true }
    add_reference :workout_exercises,
      :template_exercise,
      foreign_key: true
  end
end
