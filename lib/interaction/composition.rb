# frozen_string_literal: true

module Interaction
  #
  # Adds `#run` to instances for composing interactions. `run` calls
  # a sub-interaction; if it fails, the parent inherits its details
  # (including code and error) and halts by raising Interaction::Halt.
  # If it succeeds, `run` returns the sub-result's details hash so the
  # caller can destructure fields from it.
  #
  # Usage:
  #
  #   class CreateGoalAndFollow < Interaction::Base
  #     transactional
  #
  #     input :user, User, required: true
  #     input :name, String, required: true
  #
  #     def call
  #       goal_details = run GoalTracking::AddGoal, user: user, name: name
  #       # if AddGoal failed, we never got here — parent already failed
  #
  #       run Social::FollowGoal, user: user, goal: goal_details[:goal]
  #
  #       result.details = { goal: goal_details[:goal] }
  #     end
  #   end
  #
  # Halt is rescued in `Base.call`. Because it is an exception, any
  # transaction it passes through (the parent's `transactional` one, or a
  # hand-written `ActiveRecord::Base.transaction` block) rolls back.
  #
  # `run_interaction` is an alias that can't be shadowed by an input
  # named `run`.
  #
  module Composition
    def run(interaction_class, **args)
      sub_result = interaction_class.call(**args)
      if sub_result.failure?
        result.fail_with(**sub_result.details)
        raise Halt
      end
      sub_result.details
    end
    alias_method :run_interaction, :run
  end
end
