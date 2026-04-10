# frozen_string_literal: true

module Interaction
  #
  # Class-level `before_call` and `after_call` hook declarations.
  # Hooks are invoked from `Base.call` (the class method), not via
  # prepended `#call` methods — the class method is the single choke
  # point that wraps every interaction run.
  #
  # Usage:
  #
  #   class AddGoal < Interaction::Base
  #     before_call :log_start
  #     after_call  :enqueue_gamification
  #
  #     def call
  #       # ...
  #     end
  #
  #     private
  #
  #     def log_start
  #       Rails.logger.info("AddGoal starting for user=#{user_id}")
  #     end
  #
  #     def enqueue_gamification
  #       return if result.failure?
  #       enqueue Gamification::CreateGoalActionJob, user_id
  #     end
  #   end
  #
  # `after_call` hooks run regardless of success or failure. They
  # can inspect `result.failure?` to opt out.
  #
  # Subclasses inherit their parent's hook lists via `inherited`.
  #
  module Hooks
    class << self
      def included(base)
        base.extend ClassMethods
      end
    end

    module ClassMethods
      def before_call(*method_names)
        before_call_hooks.concat(method_names)
      end

      def after_call(*method_names)
        after_call_hooks.concat(method_names)
      end

      def before_call_hooks
        @before_call_hooks ||= []
      end

      def after_call_hooks
        @after_call_hooks ||= []
      end

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@before_call_hooks, before_call_hooks.dup)
        subclass.instance_variable_set(:@after_call_hooks, after_call_hooks.dup)
      end
    end
  end
end
