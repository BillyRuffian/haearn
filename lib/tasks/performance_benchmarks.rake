namespace :performance do
  desc 'Benchmark dashboard analytics and notification refresh timings'
  task benchmark_dashboard: :environment do
    user = if ENV['USER_ID'].present?
      User.find_by(id: ENV['USER_ID'])
    else
      User.where(deactivated_at: nil).order(:id).first
    end

    unless user
      puts 'No active user found. Pass USER_ID=<id> to benchmark a specific user.'
      next
    end

    runs = [ ENV.fetch('RUNS', 10).to_i, 1 ].max
    warmup = [ ENV.fetch('WARMUP', 2).to_i, 0 ].max

    puts "Benchmark user: ##{user.id} (#{user.email_address})"
    puts "Warmup runs: #{warmup}, measured runs: #{runs}"

    benchmark = lambda do |name, &block|
      warmup.times { block.call }
      measurements = runs.times.map do
        query_count = 0
        subscriber = lambda do |_event, _started, _finished, _id, payload|
          next if payload[:cached] || payload[:name].in?(%w[SCHEMA TRANSACTION])

          query_count += 1
        end
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        ActiveSupport::Notifications.subscribed(subscriber, 'sql.active_record') { block.call }
        finished = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        { milliseconds: (finished - started) * 1000.0, queries: query_count }
      end

      timings = measurements.pluck(:milliseconds)
      queries = measurements.pluck(:queries)
      avg_ms = timings.sum / timings.length
      min_ms = timings.min
      max_ms = timings.max

      puts format(
        '%-36s avg: %8.2f ms   min: %8.2f ms   max: %8.2f ms   queries: %d',
        name, avg_ms, min_ms, max_ms, queries.max
      )
    end

    original_session = Current.session
    benchmark_session = user.sessions.create!
    Current.session = benchmark_session

    begin
      calculator = DashboardAnalyticsCalculator.new(user: user)
      DashboardAnalyticsCalculator::KEY_METHODS.each_key do |key|
        benchmark.call("analytics##{key}") do
          calculator.calculate(key)
        end
      end

      benchmark.call('performance_notification_service#refresh!') do
        PerformanceNotificationService.new(user: user).refresh!
      end
    ensure
      Current.session = original_session
      benchmark_session.destroy!
    end
  end
end
