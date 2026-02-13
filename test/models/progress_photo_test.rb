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
require 'test_helper'

class ProgressPhotoTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @photo = progress_photos(:front_photo)
  end

  # --- Validations ---

  test 'valid with required attributes and attached photo' do
    photo = ProgressPhoto.new(user: @user, taken_at: Time.current, category: 'front')
    photo.photo.attach(
      io: StringIO.new('fake image data'),
      filename: 'test.jpg',
      content_type: 'image/jpeg'
    )
    assert photo.valid?
  end

  test 'invalid without taken_at' do
    photo = ProgressPhoto.new(user: @user, category: 'front')
    photo.photo.attach(io: StringIO.new('data'), filename: 't.jpg', content_type: 'image/jpeg')
    assert_not photo.valid?
    assert_includes photo.errors[:taken_at], "can't be blank"
  end

  test 'invalid without photo attachment' do
    photo = ProgressPhoto.new(user: @user, taken_at: Time.current, category: 'front')
    assert_not photo.valid?
    assert_includes photo.errors[:photo], "can't be blank"
  end

  test 'valid categories' do
    ProgressPhoto::CATEGORIES.each do |cat|
      photo = ProgressPhoto.new(user: @user, taken_at: Time.current, category: cat)
      photo.photo.attach(io: StringIO.new('data'), filename: 't.jpg', content_type: 'image/jpeg')
      assert photo.valid?, "Expected category '#{cat}' to be valid"
    end
  end

  test 'invalid category rejected' do
    photo = ProgressPhoto.new(user: @user, taken_at: Time.current, category: 'nonsense')
    photo.photo.attach(io: StringIO.new('data'), filename: 't.jpg', content_type: 'image/jpeg')
    assert_not photo.valid?
    assert_includes photo.errors[:category], 'is not included in the list'
  end

  test 'nil category allowed' do
    photo = ProgressPhoto.new(user: @user, taken_at: Time.current, category: nil)
    photo.photo.attach(io: StringIO.new('data'), filename: 't.jpg', content_type: 'image/jpeg')
    assert photo.valid?
  end

  # --- Scopes ---

  test 'ordered scope returns newest first' do
    old_photo = ProgressPhoto.new(user: @user, taken_at: 30.days.ago, category: 'front')
    old_photo.photo.attach(io: StringIO.new('data'), filename: 'old.jpg', content_type: 'image/jpeg')
    old_photo.save!

    new_photo = ProgressPhoto.new(user: @user, taken_at: 1.day.ago, category: 'front')
    new_photo.photo.attach(io: StringIO.new('data'), filename: 'new.jpg', content_type: 'image/jpeg')
    new_photo.save!

    results = @user.progress_photos.ordered
    assert results.index(new_photo) < results.index(old_photo)
  end

  test 'by_category scope filters correctly' do
    front = ProgressPhoto.new(user: @user, taken_at: Time.current, category: 'front')
    front.photo.attach(io: StringIO.new('data'), filename: 'f.jpg', content_type: 'image/jpeg')
    front.save!

    back = ProgressPhoto.new(user: @user, taken_at: Time.current, category: 'back')
    back.photo.attach(io: StringIO.new('data'), filename: 'b.jpg', content_type: 'image/jpeg')
    back.save!

    results = @user.progress_photos.by_category('front')
    assert_includes results, front
    assert_not_includes results, back
  end

  # --- Helper Methods ---

  test 'category_label returns human-readable label' do
    assert_equal 'Front', ProgressPhoto.new(category: 'front').category_label
    assert_equal 'Back', ProgressPhoto.new(category: 'back').category_label
    assert_equal 'Left Side', ProgressPhoto.new(category: 'side_left').category_label
    assert_equal 'Right Side', ProgressPhoto.new(category: 'side_right').category_label
    assert_equal 'Other', ProgressPhoto.new(category: 'other').category_label
  end

  test 'overlay_date formats correctly' do
    photo = ProgressPhoto.new(taken_at: Time.zone.parse('2026-03-15 10:30:00'))
    assert_equal 'Mar 15, 2026', photo.overlay_date
  end

  test 'overlay_time formats correctly' do
    photo = ProgressPhoto.new(taken_at: Time.zone.parse('2026-03-15 14:30:00'))
    assert_equal '2:30 PM', photo.overlay_time
  end

  test 'category_icon returns bootstrap icon class' do
    photo = ProgressPhoto.new(category: 'front')
    assert_match(/bi-/, photo.category_icon)
  end
end
