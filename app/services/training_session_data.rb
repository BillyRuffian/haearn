class TrainingSessionData
  def self.working_sets(entries)
    entries.flat_map do |entry|
      entry.exercise_sets.select { |set| set.completed_at && !set.is_warmup }
        .sort_by { |set| [ set.completed_at, set.position, set.id ] }.map do |set|
          {
            weight_kg: set.weight_kg&.to_f, reps: set.reps, rpe: set.rpe&.to_f, rir: set.rir,
            duration_seconds: set.duration_seconds, distance_meters: set.distance_meters&.to_f,
            set_type: set.set_type, is_failed: set.is_failed, spotter_assisted: set.spotter_assisted,
            is_amrap: set.is_amrap, partial_reps: set.partial_reps, pain_flag: set.pain_flag,
            equipment: set.equipment_list, band_tension_kg: set.band_tension_kg&.to_f,
            chain_weight_kg: set.chain_weight_kg&.to_f
          }.compact
        end
    end
  end

  def self.session(entries)
    entries = entries.sort_by { |entry| [ entry.workout_block.position, entry.position, entry.id ] }
    { workout_id: entries.first.workout.id, started_at: entries.first.workout.started_at.iso8601,
      sets: working_sets(entries), exercise_notes: entries.map { |entry|
        { workout_exercise_id: entry.id, session_notes: entry.session_notes.presence&.truncate(400),
          setup_notes: entry.persistent_notes.presence&.truncate(400) }
      } }
  end
end
