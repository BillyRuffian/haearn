# == Schema Information
#
# Table name: program_cycles
#
#  id                  :integer          not null, primary key
#  ended_on            :date
#  starts_on           :date             not null
#  status              :string           default("active"), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  training_program_id :integer          not null
#  user_id             :integer          not null
#
# Indexes
#
#  index_program_cycles_on_one_active_user                 (user_id) UNIQUE WHERE status = 'active'
#  index_program_cycles_on_training_program_id             (training_program_id)
#  index_program_cycles_on_training_program_id_and_status  (training_program_id,status)
#  index_program_cycles_on_user_id                         (user_id)
#
# Foreign Keys
#
#  training_program_id  (training_program_id => training_programs.id)
#  user_id              (user_id => users.id)
#
class ProgramCycle < ApplicationRecord
  STATUSES = %w[active completed cancelled].freeze

  belongs_to :training_program
  belongs_to :user
  has_many :program_session_executions, dependent: :destroy

  validates :starts_on, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate :starts_on_monday
  validate :user_owns_program

  scope :active, -> { where(status: 'active') }
  scope :recent, -> { order(starts_on: :desc) }

  delegate :weeks_count, to: :training_program

  def scheduled_sessions_on(date)
    week = week_number_on(date)
    return ProgramSession.none unless week

    training_program.program_sessions
      .where(week_number: week, weekday: date.cwday)
      .includes(workout_template: { template_blocks: { template_exercises: [ :exercise, :machine ] } })
      .order(:position)
  end

  def scheduled_on(program_session)
    starts_on + ((program_session.week_number - 1) * 7) + (program_session.weekday - 1)
  end

  def week_number_on(date)
    offset = (date - starts_on).to_i
    return nil if offset.negative? || offset >= weeks_count * 7

    (offset / 7) + 1
  end

  def ends_on
    starts_on + (weeks_count * 7) - 1
  end

  def expired?(date = Date.current)
    date > ends_on
  end

  def not_started?(date = Date.current)
    date < starts_on
  end

  def cancel!
    update!(status: 'cancelled', ended_on: Date.current)
  end

  def complete!
    update!(status: 'completed', ended_on: Date.current)
  end

  def completion_rate(as_of: Date.current)
    due_sessions = training_program.program_sessions.select { |session| scheduled_on(session) <= as_of }
    return 0 if due_sessions.empty?

    completed_ids = program_session_executions.where(status: 'completed').pluck(:program_session_id).to_set
    ((due_sessions.count { |session| completed_ids.include?(session.id) }.to_f / due_sessions.size) * 100).round
  end

  def adherence_score
    scores = program_session_executions
      .where(status: 'completed')
      .includes(workout: { workout_exercises: :exercise_sets })
      .filter_map(&:adherence_score)
    return nil if scores.empty?

    (scores.sum.to_f / scores.size).round
  end

  private

  def starts_on_monday
    return unless starts_on
    return if starts_on.monday?

    errors.add(:starts_on, 'must be a Monday')
  end

  def user_owns_program
    return unless user && training_program
    return if user_id == training_program.user_id

    errors.add(:user, 'must own the training program')
  end
end
