# frozen_string_literal: true

module Interaction
  #
  # Adds `#enqueue` to instances — a thin wrapper around ActiveJob
  # that runs synchronously in test/development and asynchronously
  # in production. Removes the `Rails.env.test? || .development?`
  # perform_now/perform_later conditional that otherwise appears in
  # every interaction that enqueues jobs.
  #
  # Usage:
  #
  #   class AddGoal < Interaction::Base
  #     def call
  #       goal = Goal.create!(...)
  #       enqueue Gamification::CreateGoalActionJob, user_id
  #       result.details = { goal: goal }
  #     end
  #   end
  #
  # The sync/async decision is driven by `Interaction.configuration.enqueue_synchronously?`.
  # See Configuration for how to override the default.
  #
  module Enqueue
    def enqueue(job_class, *args, **kwargs)
      if Interaction.configuration.enqueue_synchronously?
        if kwargs.empty?
          job_class.perform_now(*args)
        else
          job_class.perform_now(*args, **kwargs)
        end
      elsif kwargs.empty?
        job_class.perform_later(*args)
      else
        job_class.perform_later(*args, **kwargs)
      end
    end
  end
end
