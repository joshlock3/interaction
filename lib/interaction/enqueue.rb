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
  #
  # The job is handed to `Interaction.configuration.after_commit`, which
  # by default defers it until every open ActiveRecord transaction has
  # committed (and drops it if one rolls back). Outside a transaction it
  # runs immediately. This keeps a job from reading rows that aren't
  # committed yet, or acting on writes that end up rolled back.
  #
  module Enqueue
    def enqueue(job_class, *args, **kwargs)
      sync = Interaction.configuration.enqueue_synchronously?
      Interaction.configuration.after_commit.call do
        method = sync ? :perform_now : :perform_later
        if kwargs.empty?
          job_class.public_send(method, *args)
        else
          job_class.public_send(method, *args, **kwargs)
        end
      end
    end
  end
end
