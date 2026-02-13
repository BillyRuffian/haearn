# frozen_string_literal: true

# Tracks progress photos with date overlays for physique tracking
# Uses Active Storage for image attachment
# Supports categorization (front, back, side) for comparison views
#
# == Schema Information
#
# Table name: progress_photos
#
#  id         :integer          not null, primary key
#  category   :string
#  notes      :text
#  taken_at   :datetime         not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :integer          not null
#
# Indexes
#
#  index_progress_photos_on_user_id               (user_id)
#  index_progress_photos_on_user_id_and_category  (user_id,category)
#  index_progress_photos_on_user_id_and_taken_at  (user_id,taken_at)
#
# Foreign Keys
#
#  user_id  (user_id => users.id)
#
class ProgressPhoto < ApplicationRecord
  CATEGORIES = %w[front back side_left side_right other].freeze

  belongs_to :user

  has_one_attached :photo

  validates :taken_at, presence: true
  validates :category, inclusion: { in: CATEGORIES }, allow_nil: true
  validates :photo, presence: true

  scope :ordered, -> { order(taken_at: :desc) }
  scope :by_category, ->(cat) { where(category: cat) }
  scope :recent, -> { where('taken_at >= ?', 90.days.ago).ordered }

  # Human-readable category label
  def category_label
    {
      'front' => 'Front',
      'back' => 'Back',
      'side_left' => 'Left Side',
      'side_right' => 'Right Side',
      'other' => 'Other'
    }[category] || 'Uncategorized'
  end

  # Category icon (Bootstrap Icons)
  def category_icon
    {
      'front' => 'bi-person-standing',
      'back' => 'bi-person-standing',
      'side_left' => 'bi-person-standing',
      'side_right' => 'bi-person-standing',
      'other' => 'bi-camera'
    }[category] || 'bi-camera'
  end

  # Get nearest bodyweight to this photo's date for overlay
  def bodyweight_at_time
    user.body_metrics
        .with_weight
        .where('measured_at <= ?', taken_at + 3.days)
        .where('measured_at >= ?', taken_at - 3.days)
        .order(Arel.sql("ABS(strftime('%s', measured_at) - #{taken_at.to_i})"))
        .first
        &.weight_kg
  end

  # Format the date for overlay display
  def overlay_date
    taken_at.strftime('%b %-d, %Y')
  end

  # Format the time for overlay display
  def overlay_time
    taken_at.strftime('%-I:%M %p')
  end
end
