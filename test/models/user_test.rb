# == Schema Information
#
# Table name: users
#
#  id                   :integer          not null, primary key
#  default_rest_seconds :integer          default(90)
#  email_address        :string           not null
#  name                 :string
#  password_digest      :string           not null
#  preferred_unit       :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  default_gym_id       :integer
#
# Indexes
#
#  index_users_on_default_gym_id  (default_gym_id)
#  index_users_on_email_address   (email_address) UNIQUE
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
