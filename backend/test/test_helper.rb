ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

require_relative "support/helpers"
require_relative "support/test_adapters"

module ActiveSupport
  class TestCase
    # Deterministic, single-process execution. The test database is a single
    # SQLite file; parallel workers add lock contention without benefit here.
    parallelize(workers: 1)

    include SupportHelpers
  end
end

class ActionDispatch::IntegrationTest
  include SupportHelpers
end