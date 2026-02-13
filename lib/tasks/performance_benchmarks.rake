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
      timings = runs.times.map do
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        block.call
        finished = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        (finished - started) * 1000.0
      end

      avg_ms = timings.sum / timings.length
      min_ms = timings.min
      max_ms = timings.max

      puts format('%-36s avg: %8.2f ms   min: %8.2f ms   max: %8.2f ms', name, avg_ms, min_ms, max_ms)
    end

    original_session = Current.session
    benchmark_session = user.sessions.create!
    Current.session = benchmark_session

    begin
      dashboard = DashboardController.new

      benchmark.call('dashboard#load_dashboard_data') do
        dashboard.send(:load_dashboard_data)
      end

      benchmark.call('dashboard#calculate_pr_timeline') do
        dashboard.send(:calculate_pr_timeline)
      end

      benchmark.call('dashboard#calculate_plateaus') do
        dashboard.send(:calculate_plateaus)
      end

      benchmark.call('dashboard#calculate_tonnage_tracker') do
        dashboard.send(:calculate_tonnage_tracker)
      end

      benchmark.call('dashboard#calculate_consistency_data') do
        dashboard.send(:calculate_consistency_data)
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
