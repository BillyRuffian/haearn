# == Schema Information
#
# Table name: users
#
#  id                       :integer          not null, primary key
#  admin                    :boolean          default(FALSE), not null
#  deactivated_at           :datetime
#  default_rest_seconds     :integer          default(90)
#  email_address            :string           not null
#  name                     :string
#  notify_plateau           :boolean          default(TRUE), not null
#  notify_readiness         :boolean          default(TRUE), not null
#  notify_rest_timer_in_app :boolean          default(TRUE), not null
#  notify_rest_timer_push   :boolean          default(TRUE), not null
#  notify_streak_risk       :boolean          default(TRUE), not null
#  notify_volume_drop       :boolean          default(TRUE), not null
#  password_digest          :string           not null
#  preferred_unit           :string
#  progression_rep_target   :integer          default(10), not null
#  weekly_summary_email     :boolean          default(FALSE), not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  default_gym_id           :integer
#
# Indexes
#
#  index_users_on_admin           (admin)
#  index_users_on_created_at      (created_at)
#  index_users_on_default_gym_id  (default_gym_id)
#  index_users_on_email_address   (email_address) UNIQUE
#  index_users_on_updated_at      (updated_at)
#
# Foreign Keys
#
#  default_gym_id  (default_gym_id => gyms.id)
#
require 'test_helper'

class UserTest < ActiveSupport::TestCase
  test 'downcases and strips email_address' do
    user = User.new(email_address: ' DOWNCASED@EXAMPLE.COM ')
    assert_equal('downcased@example.com', user.email_address)
  end
end
