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
        workout_frequency
        consistency
        rep_range_distribution
        exercise_frequency
        streaks
        week_comparison
        tonnage
        training_period_totals
        plateaus
        training_density
        muscle_group_volume
        muscle_balance
      ])
      expect(data[:pr_timeline_data]).to eq([ 'pr_timeline' ])
      expect(data[:consistency_data]).to eq([ 'consistency' ])
      expect(data[:training_period_totals]).to eq([ 'training_period_totals' ])
      expect(data[:muscle_balance_data]).to eq([ 'muscle_balance' ])
      expect(data).not_to have_key(:workouts_this_week)
      expect(data).not_to have_key(:fatigue_data)
    end

    it 'loads the bounded session-duration series in one query' do
      builder = described_class.new(user: user, analytics_fetcher: ->(_key) { [] })

      query_count = count_sql_queries { builder.analytics_data }

      expect(query_count).to eq(1)
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

  def count_sql_queries
    count = 0
    callback = lambda do |_name, _started, _finished, _unique_id, payload|
      next if payload[:cached]
      next if payload[:name].in?(%w[SCHEMA TRANSACTION])
      next if payload[:sql].match?(/\A(?:BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/)

      count += 1
    end

    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
      ActiveRecord::Base.uncached { yield }
    end

    count
  end
end
