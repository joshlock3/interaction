# frozen_string_literal: true

require_relative "input"
require_relative "input_delegator"
require_relative "input_validator"
require_relative "input_dsl"
require_relative "guard"
require_relative "hooks"
require_relative "composition"
require_relative "enqueue"
require_relative "result"
require_relative "exception"

module Interaction
  class Base
    include InputDelegator
    include InputValidator
    include Guard
    include InputDsl
    include Hooks
    include Composition
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

      catch(:halt_interaction) do
        run_hooks(instance, before_call_hooks)
        begin
          instance.call
        rescue => error
          instance.handle_exception(error)
        end
      end

      run_hooks(instance, after_call_hooks)
      instance.result
    end

    def self.run_hooks(instance, hooks)
      hooks.each { |hook| instance.send(hook) }
    end
    private_class_method :run_hooks

    def call
      # overwritten by inheritors
    end

    def handle_exception(error)
      Exception.report(
        error: error,
        tags: input.to_h,
        class_name: self.class.name
      )

      fail_from_exception(error: error.message)
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
  end
end
