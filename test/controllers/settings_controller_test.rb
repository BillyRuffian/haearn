require 'test_helper'

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test 'should get show' do
    get settings_path
    assert_response :success
    assert_select 'h1', text: /Settings/
  end

  test 'should update profile' do
    patch settings_path, params: { user: { name: 'New Name', email_address: 'new@example.com' } }
    assert_redirected_to settings_path

    @user.reload
    assert_equal 'New Name', @user.name
    assert_equal 'new@example.com', @user.email_address
  end

  test 'should update preferred unit' do
    patch settings_path, params: { user: { preferred_unit: 'lbs' } }
    assert_redirected_to settings_path

    @user.reload
    assert_equal 'lbs', @user.preferred_unit
  end

  test 'should update default rest seconds' do
    patch settings_path, params: { user: { default_rest_seconds: 120 } }
    assert_redirected_to settings_path

    @user.reload
    assert_equal 120, @user.default_rest_seconds
  end

  test 'should reject invalid rest seconds below minimum' do
    patch settings_path, params: { user: { default_rest_seconds: 10 } }
    assert_response :unprocessable_entity

    @user.reload
    assert_not_equal 10, @user.default_rest_seconds
  end

  test 'should reject invalid rest seconds above maximum' do
    patch settings_path, params: { user: { default_rest_seconds: 600 } }
    assert_response :unprocessable_entity

    @user.reload
    assert_not_equal 600, @user.default_rest_seconds
  end

  test 'should change password with correct current password' do
    patch update_password_settings_path, params: {
      current_password: 'password',
      password: 'newpassword123',
      password_confirmation: 'newpassword123'
    }
    assert_redirected_to settings_path

    @user.reload
    assert @user.authenticate('newpassword123')
  end

  test 'should reject password change with incorrect current password' do
    patch update_password_settings_path, params: {
      current_password: 'wrongpassword',
      password: 'newpassword123',
      password_confirmation: 'newpassword123'
    }
    assert_response :unprocessable_entity

    @user.reload
    assert @user.authenticate('password')
    assert_not @user.authenticate('newpassword123')
  end

  test 'should reject password change with blank new password' do
    patch update_password_settings_path, params: {
      current_password: 'password',
      password: '',
      password_confirmation: ''
    }
    assert_response :unprocessable_entity
  end

  test 'should require authentication' do
    sign_out

    get settings_path
    assert_redirected_to new_session_path
  end

  test 'should export data as JSON' do
    get export_data_settings_path
    assert_response :success
    assert_equal 'application/json', response.content_type.split(';').first

    data = JSON.parse(response.body)
    assert_equal @user.email_address, data['user']['email']
    assert data.key?('gyms')
    assert data.key?('exercises')
    assert data.key?('workouts')
  end

  test 'should export data as CSV' do
    get export_csv_settings_path
    assert_response :success
    assert_equal 'text/csv', response.content_type.split(';').first

    # CSV should have header row
    assert_includes response.body, 'Date,Gym,Exercise'
  end

  test 'should update notification preferences' do
    patch settings_path, params: {
      user: {
        notify_readiness: false,
        notify_plateau: false,
        notify_streak_risk: true,
        notify_volume_drop: false,
        notify_rest_timer_in_app: false,
        notify_rest_timer_push: false
      }
    }
    assert_redirected_to settings_path

    @user.reload
    assert_not @user.notify_readiness?
    assert_not @user.notify_plateau?
    assert @user.notify_streak_risk?
    assert_not @user.notify_volume_drop?
    assert_not @user.notify_rest_timer_in_app?
    assert_not @user.notify_rest_timer_push?
  end
end
