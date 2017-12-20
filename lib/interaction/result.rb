# frozen_string_literal: true

module Interaction
  #
  # The Result object is responsible for reporting the status and details
  # of the action it was initialized on. A Result is a success until it
  # is explicitly invoked to fail.
  #
  #
  # Example usage
  #   result = Result.new
  #
  #   result.fail(error: "Could not complete action")
  #
  #   if result.success?
  #     puts "yay!"
  #   else
  #     puts "boo...#{result.details[:error]}"
  #   end
  #
  #
  class Result
    attr_accessor :details
    attr_writer :custom_exception_detail

    def initialize
      @failure = false
      @details = {}
      @custom_exception_detail = {}
    end

    def success?
      !failure?
    end

    def failure?
      @failure
    end

    def fail(details = {})
      @failure = true
      @details = details
    end

    def fail_from_exception(details)
      fail(details.merge(@custom_exception_detail))
    end
  end
end
