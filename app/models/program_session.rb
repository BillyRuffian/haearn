# == Schema Information
#
# Table name: program_sessions
#
#  id                  :integer          not null, primary key
#  intensity_percent   :integer          default(100), not null
#  name                :string
#  notes               :text
#  position            :integer          default(1), not null
#  volume_percent      :integer          default(100), not null
#  week_number         :integer          not null
#  weekday             :integer          not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  training_program_id :integer          not null
#  workout_template_id :integer          not null
#
# Indexes
#
#  index_program_sessions_on_schedule             (training_program_id,week_number,weekday,position) UNIQUE
#  index_program_sessions_on_training_program_id  (training_program_id)
#  index_program_sessions_on_workout_template_id  (workout_template_id)
#
# Foreign Keys
#
#  training_program_id  (training_program_id => training_programs.id)
#  workout_template_id  (workout_template_id => workout_templates.id)
#
class ProgramSession < ApplicationRecord
  DAY_NAMES = Date::DAYNAMES.rotate.freeze
  PERCENT_RANGE = 1..200

  belongs_to :training_program
  belongs_to :workout_template
  has_many :program_session_executions, dependent: :restrict_with_error

  validates :week_number, numericality: { only_integer: true, greater_than: 0 }
  validates :weekday, numericality: { only_integer: true, in: 1..7 }
  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validates :volume_percent, :intensity_percent,
    numericality: { only_integer: true, in: PERCENT_RANGE }
  validate :week_within_program
  validate :template_owned_by_program_user
  validate :preserve_executed_schedule, on: :update

  before_validation :assign_position
  before_destroy :preserve_execution_history

  scope :ordered, -> { order(:week_number, :weekday, :position) }

  def day_name
    DAY_NAMES.fetch(weekday - 1)
  end

  def display_name
    name.presence || workout_template.name
  end

  private

  def assign_position
    return unless training_program && week_number && weekday
    return if persisted? && !will_save_change_to_week_number? && !will_save_change_to_weekday?

    self.position = training_program.program_sessions
      .where(week_number: week_number, weekday: weekday)
      .where.not(id: id)
      .maximum(:position).to_i + 1
  end

  def week_within_program
    return unless training_program && week_number
    return if week_number <= training_program.weeks_count

    errors.add(:week_number, "must be within the program's #{training_program.weeks_count} weeks")
  end

  def template_owned_by_program_user
    return unless workout_template && training_program
    return if workout_template.user_id == training_program.user_id

    errors.add(:workout_template, 'must belong to the program owner')
  end

  def preserve_executed_schedule
    return unless program_session_executions.exists?
    return unless changes_to_save.except('name', 'notes', 'updated_at').any?

    errors.add(:base, 'Executed sessions cannot change their schedule or prescription')
  end

  def preserve_execution_history
    return unless program_session_executions.exists?

    errors.add(:base, 'Executed sessions cannot be removed')
    throw(:abort)
  end
end
