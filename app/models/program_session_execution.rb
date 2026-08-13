# == Schema Information
#
# Table name: program_session_executions
#
#  id                    :integer          not null, primary key
#  adjustment_notes      :text
#  adjustment_reason     :string
#  completed_at          :datetime
#  intensity_percent     :integer          default(100), not null
#  prescribed_sets       :integer          default(0), not null
#  prescribed_volume_kg  :decimal(12, 3)   default(0.0), not null
#  prescription          :json             not null
#  scheduled_on          :date             not null
#  session_name          :string           not null
#  skip_notes            :text
#  skip_reason           :string
#  status                :string           default("planned"), not null
#  volume_percent        :integer          default(100), not null
#  workout_template_name :string           not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  program_cycle_id      :integer          not null
#  program_session_id    :integer          not null
#
# Indexes
#
#  idx_on_program_cycle_id_scheduled_on_de2e8040e9         (program_cycle_id,scheduled_on)
#  index_program_executions_on_cycle_and_session           (program_cycle_id,program_session_id) UNIQUE
#  index_program_session_executions_on_program_cycle_id    (program_cycle_id)
#  index_program_session_executions_on_program_session_id  (program_session_id)
#
# Foreign Keys
#
#  program_cycle_id    (program_cycle_id => program_cycles.id)
#  program_session_id  (program_session_id => program_sessions.id)
#
class ProgramSessionExecution < ApplicationRecord
  STATUSES = %w[planned in_progress completed skipped].freeze
  REASONS = %w[equipment_busy fatigue pain time other].freeze

  belongs_to :program_cycle
  belongs_to :program_session
  has_one :workout, dependent: :nullify

  validates :scheduled_on, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :skip_reason, inclusion: { in: REASONS }, allow_nil: true
  validates :adjustment_reason, inclusion: { in: REASONS }, allow_nil: true
  validates :volume_percent, :intensity_percent,
    numericality: { only_integer: true, in: ProgramSession::PERCENT_RANGE }
  validate :session_belongs_to_cycle_program
  validate :skip_reason_required
  validate :adjustment_reason_required
  before_validation :snapshot_names, on: :create

  def complete_from_workout!
    update!(status: 'completed', completed_at: workout&.finished_at || Time.current)
  end

  def in_progress?
    status == 'in_progress'
  end

  def completed?
    status == 'completed'
  end

  def skipped?
    status == 'skipped'
  end

  def display_name
    session_name.presence || workout_template_name
  end

  def adherence_score
    return nil unless workout&.completed?

    scores = []
    scores << ratio_score(actual_sets, prescribed_sets) if prescribed_sets.positive?
    scores << ratio_score(actual_volume_kg, prescribed_volume_kg) if prescribed_volume_kg.positive?
    return nil if scores.empty?

    (scores.sum / scores.size).round
  end

  def actual_sets
    return 0 unless workout

    sets = loaded_working_sets
    sets ? sets.size : workout.exercise_sets.where(is_warmup: false).count
  end

  def actual_volume_kg
    return 0 unless workout

    if (sets = loaded_working_sets)
      sets.sum { |set| set.weight_kg.to_d * set.reps.to_i }
    else
      workout.exercise_sets.where(is_warmup: false).sum('COALESCE(weight_kg, 0) * COALESCE(reps, 0)')
    end
  end

  def progress_rows
    exercises = if workout
      relation = workout.workout_exercises
      relation = relation.includes(:exercise_sets) unless relation.loaded?
      relation.index_by(&:template_exercise_id)
    else
      {}
    end

    prescription.map do |row|
      workout_exercise = exercises[row['template_exercise_id']]
      actual = workout_exercise&.exercise_sets&.count { |set| set.is_warmup == false }.to_i
      target = row['target_sets'].to_i
      row.merge('actual_sets' => actual, 'complete' => target.positive? && actual >= target)
    end
  end

  def prescription_for(workout_exercise)
    prescription.find { |row| row['template_exercise_id'] == workout_exercise.template_exercise_id }
  end

  private

  def loaded_working_sets
    return unless workout.workout_exercises.loaded?
    return unless workout.workout_exercises.all? { |exercise| exercise.exercise_sets.loaded? }

    workout.workout_exercises.flat_map(&:exercise_sets).reject(&:is_warmup)
  end

  def ratio_score(actual, planned)
    [ (actual.to_f / planned.to_f) * 100, 100 ].min
  end

  def session_belongs_to_cycle_program
    return unless program_cycle && program_session
    return if program_session.training_program_id == program_cycle.training_program_id

    errors.add(:program_session, 'must belong to the cycle program')
  end

  def skip_reason_required
    errors.add(:skip_reason, 'must be selected') if status == 'skipped' && skip_reason.blank?
  end

  def adjustment_reason_required
    return unless program_session
    return if volume_percent == program_session.volume_percent && intensity_percent == program_session.intensity_percent
    return if adjustment_reason.present?

    errors.add(:adjustment_reason, 'must be selected when changing today’s prescription')
  end

  def snapshot_names
    return unless program_session

    self.session_name ||= program_session.display_name
    self.workout_template_name ||= program_session.workout_template.name
  end
end
