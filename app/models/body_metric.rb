# frozen_string_literal: true

# Tracks bodyweight and body measurements over time
# Used for progress tracking, relative strength calculations, and Wilks score
# == Schema Information
#
# Table name: body_metrics
#
#  id           :integer          not null, primary key
#  chest_cm     :decimal(5, 1)
#  hips_cm      :decimal(5, 1)
#  left_arm_cm  :decimal(5, 1)
#  left_leg_cm  :decimal(5, 1)
#  measured_at  :datetime         not null
#  notes        :text
#  right_arm_cm :decimal(5, 1)
#  right_leg_cm :decimal(5, 1)
#  waist_cm     :decimal(5, 1)
#  weight_kg    :decimal(5, 2)
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  user_id      :integer          not null
#
# Indexes
#
#  index_body_metrics_on_user_id                  (user_id)
#  index_body_metrics_on_user_id_and_measured_at  (user_id,measured_at)
#
# Foreign Keys
#
#  user_id  (user_id => users.id)
#
class BodyMetric < ApplicationRecord
  belongs_to :user

  validates :measured_at, presence: true
  validates :weight_kg, numericality: { greater_than: 0, less_than: 500 }, allow_nil: true
  validates :chest_cm, :waist_cm, :hips_cm, :left_arm_cm, :right_arm_cm, :left_leg_cm, :right_leg_cm,
            numericality: { greater_than: 0, less_than: 300 }, allow_nil: true

  scope :ordered, -> { order(measured_at: :desc) }
  scope :recent, -> { where('measured_at >= ?', 90.days.ago).ordered }
  scope :with_weight, -> { where.not(weight_kg: nil) }
  scope :with_measurements, -> { where.not(chest_cm: nil).or(where.not(waist_cm: nil)) }

  # Get the most recent bodyweight for the user
  def self.current_weight_kg
    with_weight.ordered.first&.weight_kg
  end

  # Calculate weight change from previous entry
  def weight_change_kg
    return nil unless weight_kg

    previous = user.body_metrics
                   .with_weight
                   .where('measured_at < ?', measured_at)
                   .ordered
                   .first

    return nil unless previous

    weight_kg - previous.weight_kg
  end

  # Check if this entry has any measurements (not just weight)
  def has_measurements?
    chest_cm.present? || waist_cm.present? || hips_cm.present? ||
      left_arm_cm.present? || right_arm_cm.present? ||
      left_leg_cm.present? || right_leg_cm.present?
  end

  # Display weight in user's preferred unit
  def weight_display
    return '—' unless weight_kg

    WeightConverter.kg_to_user_unit_display(weight_kg, user)
  end
end
