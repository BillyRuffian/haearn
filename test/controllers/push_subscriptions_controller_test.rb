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

  test 're-associates existing endpoint from another user to current user' do
    other_user = users(:two)
    existing = other_user.push_subscriptions.create!(
      endpoint: 'https://example.push/subscriptions/shared',
      p256dh_key: 'old-p256dh',
      auth_key: 'old-auth'
    )

    assert_no_difference('PushSubscription.count') do
      post push_subscriptions_path,
           params: {
             subscription: {
               endpoint: existing.endpoint,
               expiration_time: nil,
               keys: {
                 p256dh: 'new-p256dh',
                 auth: 'new-auth'
               }
             }
           },
           as: :json
    end

    assert_response :success
    existing.reload
    assert_equal @user.id, existing.user_id
    assert_equal 'new-p256dh', existing.p256dh_key
    assert_equal 'new-auth', existing.auth_key
  end
end
