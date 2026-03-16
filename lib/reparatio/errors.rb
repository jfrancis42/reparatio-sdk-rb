module Reparatio
  # Base class for all Reparatio errors.
  class Error < StandardError; end

  # Missing, invalid, or expired API key.
  class AuthenticationError < Error; end

  # The operation requires a Professional plan.
  class InsufficientPlanError < Error; end

  # The file exceeds the server's size limit.
  class FileTooLargeError < Error; end

  # The file could not be parsed in the detected format.
  class ParseError < Error; end

  # Unexpected server error.
  class APIError < Error
    attr_reader :status_code
    def initialize(status_code, message)
      @status_code = status_code
      super(message)
    end
  end
end
