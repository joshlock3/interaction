# frozen_string_literal: true

module Interaction
  #
  # Adds the `transactional` class macro. A transactional interaction
  # runs its whole `#call` (input validation and guards included) inside
  # `Interaction.configuration.transaction`, which by default is
  # `ActiveRecord::Base.transaction(requires_new: true)`.
  #
  # The transaction rolls back when:
  #   * the result fails (fail_with, a failed guard, a failed `run`), or
  #   * `#call` raises.
  #
  # If `#call` raises ActiveRecord::Rollback, ActiveRecord swallows it; the
  # interaction detects that the body never finished and fails with
  # code :server_error ("Transaction was rolled back") rather than
  # reporting success for writes that were discarded.
  #
  # Usage:
  #
  #   class TransferPoints < Interaction::Base
  #     transactional
  #
  #     input :from, User
  #     input :to, User
  #
  #     def call
  #       from.decrement!(:points, 10)
  #       return fail_with(error: "Overdrawn", code: :conflict) if from.points.negative?
  #       to.increment!(:points, 10)
  #     end
  #   end
  #
  # `requires_new: true` means a transactional interaction called inside
  # another transaction gets its own savepoint, so its failure rolls back
  # only its own writes. Subclasses inherit the setting; `transactional false`
  # turns it off again.
  #
  # A custom `config.transaction` must also open a real savepoint
  # (`requires_new: true`). Otherwise, nested in an outer transaction, it
  # merely joins it: a halt or failure is detected but the writes are not
  # rolled back.
  #
  module Transaction
    class << self
      def included(base)
        base.extend ClassMethods
      end
    end

    module ClassMethods
      def transactional(enabled = true)
        @transactional = enabled
      end

      def transactional?
        return @transactional if defined?(@transactional)
        superclass.respond_to?(:transactional?) ? superclass.transactional? : false
      end
    end

    ROLLBACK_MESSAGE = "Transaction was rolled back"

    private

    def _within_transaction(&block)
      if self.class.transactional?
        completed = false
        Interaction.configuration.transaction.call do
          block.call
          completed = true
        end
        # ActiveRecord's `transaction` swallows ActiveRecord::Rollback, so a
        # block that raised it returns normally without finishing. Halt and
        # other exceptions propagate instead and never reach this line.
        unless completed
          fail_with(error: ROLLBACK_MESSAGE, code: :server_error)
        end
      else
        yield
      end
    end
  end
end
