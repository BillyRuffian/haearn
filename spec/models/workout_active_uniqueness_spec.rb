require 'rails_helper'

RSpec.describe Workout, type: :model do
  let(:user) { users(:one) }
  let(:gym) { gyms(:one) }

  before do
    user.workouts.in_progress.destroy_all
  end

  it 'allows only one active workout per user at validation and database layers' do
    active_workout = user.workouts.create!(gym:, started_at: 10.minutes.ago)
    duplicate = user.workouts.build(gym:, started_at: Time.current)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:user_id]).to include('already has an active workout')

    expect do
      duplicate.save!(validate: false)
    end.to raise_error(ActiveRecord::RecordNotUnique)
    expect(user.workouts.in_progress).to contain_exactly(active_workout)
  end

  it 'allows another workout after the active workout is finished' do
    first_workout = user.workouts.create!(gym:, started_at: 30.minutes.ago)
    first_workout.update!(finished_at: Time.current)

    expect do
      user.workouts.create!(gym:, started_at: Time.current)
    end.to change(user.workouts.in_progress, :count).from(0).to(1)
  end
end
