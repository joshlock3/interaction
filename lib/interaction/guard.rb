# frozen_string_literal: true

module Interaction
  #
  # The `guard` DSL formalizes the "bail out early if preconditions
  # aren't met" pattern. Each declared guard is an instance method
  # that runs in order before the body of `#call`. A guard that calls
  # `fail_with` (or otherwise marks the result as failed) halts the
  # chain — the remaining guards and the body are skipped.
  #
  # Usage:
  #
  #   class AddGoal < Interaction::Base
  #     input :current_user, User, required: true
  #
  #     guard :must_be_authenticated
  #     guard :must_be_admin
  #
  #     def call
  #       # preconditions already passed
  #     end
  #
  #     private
  #
  #     def must_be_authenticated
  #       fail_with(error: "Authentication required", code: :unauthorized) if current_user.nil?
  #     end
  #
  #     def must_be_admin
  #       fail_with(error: "Admin only", code: :forbidden) unless current_user.admin?
  #     end
  #   end
  #
  # Guards run AFTER input validation (so they can assume declared
  # inputs are valid) but BEFORE the body of `#call`.
  #
  # Subclasses inherit their parent's guard list via `inherited`.
  #
  module Guard
    class << self
      def included(base)
        base.extend ClassMethods
      end
    end

    module ClassMethods
      def guard(*method_names)
        declared_guards.concat(method_names)
      end

      def declared_guards
        @declared_guards ||= []
      end

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@declared_guards, declared_guards.dup)
      end
    end

    module InstanceMethods
      def call
        self.class.declared_guards.each do |guard_method|
          send(guard_method)
          break if result.failure?
        end
        return if result.failure?
        super
      end
    end
  end
end
