require 'rails_helper'

RSpec.describe DashboardPageDataBuilder do
  let(:user) { users(:one) }

  describe '#analytics_data' do
    it 'builds the shared analytics payload via the analytics fetcher' do
      requested_keys = []
      builder = described_class.new(
        user: user,
        analytics_fetcher: lambda { |key|
          requested_keys << key
          [ key ]
        }
      )

      data = builder.analytics_data

      expect(requested_keys).to match_array(%w[
        pr_timeline
        consistency
        rep_range_distribution
        exercise_frequency
        streaks
        week_comparison
        tonnage
        plateaus
        training_density
        muscle_group_volume
        muscle_balance
      ])
      expect(data[:pr_timeline_data]).to eq([ 'pr_timeline' ])
      expect(data[:consistency_data]).to eq([ 'consistency' ])
      expect(data[:muscle_balance_data]).to eq([ 'muscle_balance' ])
      expect(data).not_to have_key(:workouts_this_week)
      expect(data).not_to have_key(:fatigue_data)
    end
  end

  describe '#index_data' do
    it 'adds overview-only dashboard data on top of the shared analytics payload' do
      builder = described_class.new(
        user: user,
        analytics_fetcher: lambda { |key|
          key == 'pr_timeline' ? [ { date: Date.current.iso8601 } ] : []
        }
      )

      data = builder.index_data

      expect(data[:workouts_this_week]).to be_a(Integer)
      expect(data[:volume_this_week]).to be_a(Integer)
      expect(data[:prs_this_month]).to eq(1)
      expect(data[:current_weight_kg]).to eq(user.body_metrics.current_weight_kg)
      expect(data[:recent_workouts]).to all(be_a(Workout))
      expect(data[:fatigue_data]).to eq([])
      expect(data[:readiness_alerts]).to eq([])
    end
  end
end
