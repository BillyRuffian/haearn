require 'test_helper'

class UserPolicyTest < ActiveSupport::TestCase
  setup do
    @admin = users(:admin)
    @user = users(:one)
    @other_user = users(:two)
  end

  test 'admin can list users' do
    assert UserPolicy.new(@admin, User).index?
  end

  test 'regular user cannot list users' do
    assert_not UserPolicy.new(@user, User).index?
  end

  test 'admin can show any user' do
    assert UserPolicy.new(@admin, @other_user).show?
  end

  test 'user can show themselves' do
    assert UserPolicy.new(@user, @user).show?
  end

  test 'user cannot show other users' do
    assert_not UserPolicy.new(@user, @other_user).show?
  end

  test 'admin can toggle admin on other users' do
    assert UserPolicy.new(@admin, @user).toggle_admin?
  end

  test 'admin cannot toggle admin on themselves' do
    assert_not UserPolicy.new(@admin, @admin).toggle_admin?
  end

  test 'regular user cannot toggle admin' do
    assert_not UserPolicy.new(@user, @other_user).toggle_admin?
  end

  test 'admin can deactivate other users' do
    assert UserPolicy.new(@admin, @user).deactivate?
  end

  test 'admin cannot deactivate themselves' do
    assert_not UserPolicy.new(@admin, @admin).deactivate?
  end

  test 'admin can impersonate active users' do
    assert UserPolicy.new(@admin, @user).impersonate?
  end

  test 'admin cannot impersonate themselves' do
    assert_not UserPolicy.new(@admin, @admin).impersonate?
  end

  test 'admin cannot impersonate deactivated users' do
    @user.update!(deactivated_at: Time.current)
    assert_not UserPolicy.new(@admin, @user).impersonate?
  end

  test 'scope returns all users for admin' do
    scope = UserPolicy::Scope.new(@admin, User).resolve
    assert_equal User.count, scope.count
  end

  test 'scope returns only self for regular user' do
    scope = UserPolicy::Scope.new(@user, User).resolve
    assert_equal 1, scope.count
    assert_includes scope, @user
  end
end
