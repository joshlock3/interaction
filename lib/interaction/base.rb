# frozen_string_literal: true

require_relative 'input'
require_relative 'input_delegator'
require_relative 'input_validator'
require_relative 'result'
require_relative 'exception'

module Interaction
  class Base
    include InputDelegator
    include InputValidator

    attr_reader :input, :result

    def initialize(args)
      @input = Input.new(args)
      @result = Result.new
    end

    def self.call(args = {})
      instance = new(args)

      begin
        instance.call
      rescue => error
        instance.handle_exception(error)
      end

      instance.result
    end

    def call
      # overwritten by inheritors
    end

    def handle_exception(error)
      Exception.report(
        error: error,
        tags: input.to_h,
        class_name: self.class.name
      )

      fail_from_exception(exeception: error.message)
    end

    def fail_from_exception(args)
      result.fail_from_exception(args)
    end

    def custom_exception_detail=(args)
      result.custom_exception_detail = args
    end
  end
end
