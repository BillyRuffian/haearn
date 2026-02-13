require 'test_helper'

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)

    @notification = @user.notifications.create!(
      kind: 'streak_risk',
      severity: 'warning',
      title: 'Test Notification',
      message: 'Time to train.',
      dedupe_key: "test:#{SecureRandom.hex(4)}",
      metadata: {}
    )
  end

  test 'should get index' do
    get notifications_path
    assert_response :success
    assert_select 'h1', text: /Performance Notifications/
  end

  test 'should return feed json' do
    get feed_notifications_path, as: :json
    assert_response :success

    payload = JSON.parse(response.body)
    assert payload.key?('unread_count')
    assert payload.key?('notifications')
    assert payload['notifications'].any? { |n| n['title'] == 'Test Notification' }
  end

  test 'should mark a notification as read' do
    patch read_notification_path(@notification), as: :json
    assert_response :success

    @notification.reload
    assert @notification.read?
  end

  test 'should mark all notifications as read' do
    second = @user.notifications.create!(
      kind: 'volume_drop',
      severity: 'warning',
      title: 'Second Notification',
      message: 'Volume dropped.',
      dedupe_key: "test:#{SecureRandom.hex(4)}",
      metadata: {}
    )

    patch mark_all_read_notifications_path, as: :json
    assert_response :success

    @notification.reload
    second.reload
    assert @notification.read?
    assert second.read?
  end

  test 'should create rest timer notification' do
    assert_difference -> { @user.notifications.count }, 1 do
      post rest_timer_expired_notifications_path,
           params: { completed_at_ms: 1_739_472_000_000 },
           as: :json
    end

    assert_response :success

    created = @user.notifications.order(:id).last
    assert_equal 'rest_timer', created.kind
    assert_equal 'Rest Complete', created.title
  end

  test 'rest timer notification should dedupe on same completion timestamp' do
    post rest_timer_expired_notifications_path,
         params: { completed_at_ms: 1_739_472_000_000 },
         as: :json
    assert_response :success

    assert_no_difference -> { @user.notifications.count } do
      post rest_timer_expired_notifications_path,
           params: { completed_at_ms: 1_739_472_000_000 },
           as: :json
    end

    assert_response :success
  end
end
