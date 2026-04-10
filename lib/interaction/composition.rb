# frozen_string_literal: true

module Interaction
  #
  # Adds `#run` to instances for composing interactions. `run` calls
  # a sub-interaction; if it fails, the parent inherits its details
  # (including code and error) and halts via `throw :halt_interaction`.
  # If it succeeds, `run` returns the sub-result's details hash so the
  # caller can destructure fields from it.
  #
  # Usage:
  #
  #   class CreateGoalAndFollow < Interaction::Base
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
  # `throw :halt_interaction` is caught in `Base.call`, so there's
  # no exception overhead — it's just a cheap non-local return.
  #
  module Composition
    def run(interaction_class, **args)
      sub_result = interaction_class.call(**args)
      if sub_result.failure?
        result.fail_with(**sub_result.details)
        throw :halt_interaction
      end
      sub_result.details
    end
  end
end
