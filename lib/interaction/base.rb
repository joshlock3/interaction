# frozen_string_literal: true

require_relative "configuration"
require_relative "errors"
require_relative "input"
require_relative "input_delegator"
require_relative "input_dsl"
require_relative "guard"
require_relative "composition"
require_relative "transaction"
require_relative "enqueue"
require_relative "result"
require_relative "exception"

module Interaction
  class Base
    include InputDelegator
    include Guard
    include InputDsl
    include Composition
    include Transaction
    include Enqueue

    attr_reader :input, :result

    def initialize(args)
      @input = Input.new(args)
      @result = Result.new
    end

    # Prepend InstanceMethods modules onto every subclass so that
    # input validation (outer) and guards (inner) wrap the subclass's
    # #call. Done here in `inherited` because prepending onto Base
    # itself would not affect subclasses — prepends on Base go
    # between Base and its superclass, not between Base and its
    # subclasses.
    def self.inherited(subclass)
      super
      subclass.prepend Guard::InstanceMethods
      subclass.prepend InputDsl::InstanceMethods
    end

    def self.call(args = {})
      instance = new(args)
      instance.__send__(:_perform)
      instance.result
    end

    # Like `call`, but raises Interaction::Failure when the result fails.
    # Returns the (successful) result otherwise.
    def self.call!(args = {})
      result = call(args)
      raise Failure.new(result, interaction: name) if result.failure?
      result
    end

    def call
      # overwritten by inheritors
    end

    def handle_exception(error)
      # A `call!` failure inside another interaction propagates like `run`:
      # it's an expected failure, not a crash, so it isn't reported.
      return result.fail_with(**error.result.details) if error.is_a?(Failure)

      config = Interaction.configuration
      mapping = config.exception_mapping_for(error)
      if mapping
        return fail_from_exception(error: mapping.message_for(error), code: mapping.code)
      end

      Exception.report(
        error: error,
        tags: {interaction: self.class.name},
        class_name: self.class.name,
        context: {interaction: Exception.context_for(self)}
      )

      fail_from_exception(error: config.exception_message_for(error))
    end

    def fail_from_exception(args)
      result.fail_from_exception(args)
    end

    def custom_exception_detail=(args)
      result.custom_exception_detail = args
    end

    # Convenience: delegates to result.fail_with so guard methods and
    # `call` bodies can write `fail_with(error: ..., code: ...)` directly.
    def fail_with(**attrs)
      result.fail_with(**attrs)
    end

    private

    # The rescues sit outside the transaction block so that both a Halt
    # (from `run`, or a failed transactional result) and an exception roll
    # the transaction back before being handled.
    def _perform
      _within_transaction do
        call
        raise Halt if self.class.transactional? && result.failure?
      end
    rescue Halt
      # result has already been failed by whoever raised the halt
    rescue => error
      handle_exception(error)
    end
  end
end
