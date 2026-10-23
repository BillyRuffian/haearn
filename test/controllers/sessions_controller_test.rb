require 'test_helper'
require_relative '../test_helpers/human_verification_test_helper'

class SessionsControllerTest < ActionDispatch::IntegrationTest
  include HumanVerificationTestHelper

  setup { @user = User.take }

  test 'new' do
    get new_session_path
    assert_response :success
  end

  test 'create with valid credentials' do
    with_verified_human do
      post session_path, params: { email_address: @user.email_address, password: 'password' }
    end

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test 'create with invalid credentials' do
    with_verified_human do
      post session_path, params: { email_address: @user.email_address, password: 'wrong' }
    end

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test 'destroy' do
    sign_in_as(User.take)

    delete session_path

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end
end
