# frozen_string_literal: true

require_relative "codes"

module Interaction
  #
  # The Result object is responsible for reporting the status and details
  # of the action it was initialized on. A Result is a success until it
  # is explicitly invoked to fail.
  #
  # Example usage
  #   result = Result.new
  #
  #   result.fail(error: "Could not complete action", code: :not_found)
  #
  #   if result.success?
  #     puts "yay!"
  #   elsif result.failed_with?(:not_found)
  #     puts "missing: #{result.error}"
  #   else
  #     puts "boo...#{result.error}"
  #   end
  #
  class Result
    attr_accessor :details
    attr_writer :custom_exception_detail
    attr_reader :code

    def initialize
      @failure = false
      @details = {}
      @custom_exception_detail = {}
      @code = nil
    end

    def success?
      !failure?
    end

    def failure?
      @failure
    end

    def error
      @details[:error]
    end

    # Returns true when the result has failed with the given code.
    #
    #   result.fail(error: "x", code: :forbidden)
    #   result.failed_with?(:forbidden)  # => true
    #   result.failed_with?(:not_found)  # => false
    def failed_with?(code)
      failure? && @code == code
    end

    # Destructive failure. Replaces @details with the given hash.
    # Kept for backwards compatibility with 3.1 and earlier.
    # Extracts :code from details if present.
    def fail(details = {})
      @failure = true
      @details = details
      @code = details[:code]
      self
    end

    # Non-destructive failure. Merges attrs into existing @details
    # instead of replacing. Prefer this in new code.
    #
    #   result.details = {draft: record}
    #   result.fail_with(error: "validation failed", code: :invalid_input)
    #   result.details # => {draft: record, error: "validation failed", code: :invalid_input}
    def fail_with(**attrs)
      @failure = true
      @details = @details.merge(attrs)
      @code = attrs[:code] if attrs.key?(:code)
      self
    end

    # Called from Base's top-level rescue. Defaults code to :server_error
    # unless the caller (or custom_exception_detail) supplied a more specific one.
    # Precedence: default < caller-supplied < custom_exception_detail.
    def fail_from_exception(details)
      merged = {code: Codes::SERVER_ERROR}.merge(details).merge(@custom_exception_detail)
      fail(merged)
    end
  end
end
