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
require "test_helper"

class BodyMetricTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
