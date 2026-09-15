require 'rails_helper'

RSpec.describe 'Workout analysis broadcasts', type: :model do
  self.use_transactional_tests = false
  include ActionCable::TestHelper

  before do
    @analysis = WorkoutAnalysis.create!(workout: workouts(:one), workout_finished_at: workouts(:one).finished_at,
      model: 'gpt-5-mini', prompt_version: 'workout-v1', request_key: SecureRandom.uuid)
    @stream = Turbo::StreamsChannel.send(:stream_name_from, [ workouts(:one), :coaching ])
    clear_messages(@stream)
  end

  after { @analysis&.destroy! }

  it 'publishes atomic job transitions after commit and sends no private analysis data' do
    WorkoutAnalysis.transaction do
      WorkoutAnalysis.update_and_broadcast(WorkoutAnalysis.where(id: @analysis.id, status: 'pending'),
        status: 'completed', summary: 'Private advice')
      expect(broadcasts(@stream)).to be_empty
    end
    expect(broadcasts(@stream).size).to eq(1)
    message = JSON.parse(broadcasts(@stream).sole)
    expect(message).to include('action="replace"', "coaching_signal_workout_#{workouts(:one).id}")
    expect(message).not_to include('Private advice', users(:one).email_address)
  end

  it 'does not broadcast rolled-back or superseded changes' do
    WorkoutAnalysis.transaction do
      WorkoutAnalysis.update_and_broadcast(WorkoutAnalysis.where(id: @analysis.id), status: 'completed')
      raise ActiveRecord::Rollback
    end
    expect(broadcasts(@stream)).to be_empty
    expect(WorkoutAnalysis.update_and_broadcast(WorkoutAnalysis.where(id: @analysis.id, processing_token: 'obsolete'), status: 'failed')).to eq(0)
    expect(broadcasts(@stream)).to be_empty
  end

  it 'broadcasts manual failures and tolerates transport failures without losing persisted status' do
    @analysis.fail_safely!('enqueue_failed')
    expect(broadcasts(@stream).size).to eq(1)
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to).and_raise(IOError, 'offline')
    expect { @analysis.update!(status: 'completed') }.not_to raise_error
    expect(@analysis.reload).to be_completed
  end
end
