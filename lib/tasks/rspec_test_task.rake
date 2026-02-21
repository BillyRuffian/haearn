# Ensure `rake test` uses RSpec for this project.
Rake::Task['test'].clear if Rake::Task.task_defined?('test')

desc 'Run RSpec test suite'
task :test do
  sh 'bundle exec rspec'
end
