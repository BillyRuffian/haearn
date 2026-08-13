# == Schema Information
#
# Table name: training_programs
#
#  id          :integer          not null, primary key
#  archived_at :datetime
#  description :text
#  name        :string           not null
#  weeks_count :integer          default(4), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  user_id     :integer          not null
#
# Indexes
#
#  index_training_programs_on_user_id                  (user_id)
#  index_training_programs_on_user_id_and_archived_at  (user_id,archived_at)
#
# Foreign Keys
#
#  user_id  (user_id => users.id)
#
class TrainingProgram < ApplicationRecord
  belongs_to :user
  has_many :program_sessions, dependent: :destroy
  has_many :program_cycles, dependent: :destroy

  validates :name, presence: true
  validates :weeks_count, numericality: { only_integer: true, in: 1..52 }
  validate :weeks_cover_schedule

  scope :available, -> { where(archived_at: nil) }
  scope :ordered, -> { order(name: :asc) }

  def activate!(starts_on:)
    if program_sessions.none?
      errors.add(:base, 'Add at least one session before activating the program')
      raise ActiveRecord::RecordInvalid.new(self)
    end

    ProgramCycle.transaction do
      ProgramCycle.active
        .joins(:training_program)
        .where(training_programs: { user_id: user_id })
        .find_each(&:cancel!)

      program_cycles.create!(user: user, starts_on: starts_on, status: 'active')
    end
  end

  def archive!
    transaction do
      program_cycles.active.find_each(&:cancel!)
      update!(archived_at: Time.current)
    end
  end

  def archived?
    archived_at.present?
  end

  private

  def weeks_cover_schedule
    return unless persisted? && weeks_count

    last_scheduled_week = program_sessions.maximum(:week_number)
    return unless last_scheduled_week && last_scheduled_week > weeks_count

    errors.add(:weeks_count, "cannot be shorter than scheduled week #{last_scheduled_week}")
  end
end
