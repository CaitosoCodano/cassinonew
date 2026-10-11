module Games
  module Adapters
    # Value object returned by every adapter operation. Adapters must never
    # raise for expected business outcomes; they return a failure Result.
    class Result
      attr_reader :data, :error_code, :error_message

      def self.success(data = {})
        new(success: true, data: data)
      end

      def self.failure(code, message = nil)
        new(success: false, error_code: code, error_message: message)
      end

      def initialize(success:, data: {}, error_code: nil, error_message: nil)
        @success = success
        @data = data || {}
        @error_code = error_code
        @error_message = error_message
      end

      def success?
        @success
      end

      def failure?
        !@success
      end
    end
  end
end
