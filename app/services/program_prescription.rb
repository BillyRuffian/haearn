class ProgramPrescription
  def initialize(program_session:, volume_percent: nil, intensity_percent: nil)
    @program_session = program_session
    @volume_percent = volume_percent || program_session.volume_percent
    @intensity_percent = intensity_percent || program_session.intensity_percent
  end

  def rows
    @rows ||= template_blocks.flat_map do |block|
      template_exercises(block).map do |template_exercise|
        build_row(template_exercise, block.position)
      end
    end
  end

  def prescribed_sets
    rows.sum { |row| row.fetch('target_sets') }
  end

  def prescribed_volume_kg
    rows.sum do |row|
      row.fetch('target_sets') * row.fetch('target_reps').to_i * row.fetch('target_weight_kg').to_d
    end
  end

  private

  def template_blocks
    blocks = @program_session.workout_template.template_blocks
    blocks.loaded? ? blocks.sort_by(&:position) : blocks.ordered
  end

  def template_exercises(block)
    exercises = block.template_exercises
    exercises.loaded? ? exercises.sort_by(&:id) : exercises.order(:id)
  end

  def build_row(template_exercise, block_position)
    {
      'template_exercise_id' => template_exercise.id,
      'block_position' => block_position,
      'exercise_id' => template_exercise.exercise_id,
      'exercise_name' => template_exercise.exercise.name,
      'machine_id' => template_exercise.machine_id,
      'machine_name' => template_exercise.machine&.name,
      'target_sets' => adjusted_sets(template_exercise.target_sets),
      'target_reps' => template_exercise.target_reps,
      'target_weight_kg' => adjusted_weight(template_exercise.target_weight_kg),
      'notes' => template_exercise.persistent_notes
    }
  end

  def adjusted_sets(target_sets)
    return 0 unless target_sets

    [ (target_sets * @volume_percent / 100.0).round, 1 ].max
  end

  def adjusted_weight(target_weight_kg)
    return 0 unless target_weight_kg

    (target_weight_kg * @intensity_percent / 100.to_d).round(4).to_f
  end
end
