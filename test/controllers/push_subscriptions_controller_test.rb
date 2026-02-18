require 'test_helper'

class PushSubscriptionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test 'creates or updates push subscription' do
    assert_difference('PushSubscription.count', 1) do
      post push_subscriptions_path,
           params: {
             subscription: {
               endpoint: 'https://example.push/subscriptions/abc',
               expiration_time: nil,
               keys: {
                 p256dh: 'test-p256dh',
                 auth: 'test-auth'
               }
             }
           },
           as: :json
    end

    assert_response :success
    subscription = @user.push_subscriptions.last
    assert_equal 'test-p256dh', subscription.p256dh_key
    assert_equal 'test-auth', subscription.auth_key
  end

  test 'deletes existing push subscription by endpoint' do
    subscription = @user.push_subscriptions.create!(
      endpoint: 'https://example.push/subscriptions/delete-me',
      p256dh_key: 'old-p256dh',
      auth_key: 'old-auth'
    )

    assert_difference('PushSubscription.count', -1) do
      delete push_subscriptions_path,
             params: { endpoint: subscription.endpoint },
             as: :json
    end

    assert_response :success
  end
end
