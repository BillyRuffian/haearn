ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'
require_relative 'test_helpers/session_test_helper'

HAEARN_PARALLEL_WORKERS = begin
  configured = ENV['PARALLEL_WORKERS']
  adapter = ActiveRecord::Base.connection_db_config&.adapter

  if configured.present?
    configured.to_i
  elsif adapter == 'sqlite3'
    1
  else
    :number_of_processors
  end
end

module ActiveSupport
  class TestCase
    # SQLite is prone to lock contention under parallel Minitest, so default to
    # single-process there unless PARALLEL_WORKERS explicitly opts into more.
    parallelize(workers: HAEARN_PARALLEL_WORKERS) unless HAEARN_PARALLEL_WORKERS == 1

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
