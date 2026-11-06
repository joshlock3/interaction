# frozen_string_literal: true

module Interaction
  #
  # Internal control-flow signal used by `run` and `transactional`.
  #
  # Inherits from ::Exception (not StandardError) so that a bare
  # `rescue => e` inside an interaction body never swallows it, while
  # an enclosing `ActiveRecord::Base.transaction` block still sees it
  # and rolls back. (A `throw` out of a transaction block commits it
  # since Rails 7.1, which is why 4.0 stopped using catch/throw.)
  #
  class Halt < ::Exception # rubocop:disable Lint/InheritException
  end

  #
  # Raised by `Interaction::Base.call!` when the interaction fails.
  #
  #   SomeInteraction.call!(user: user)
  #   # => Interaction::Failure: user is required
  #
  class Failure < StandardError
    attr_reader :result, :interaction

    def initialize(result, interaction: nil)
      @result = result
      @interaction = interaction
      super(result.error || "#{interaction || "Interaction"} failed")
    end

    def code
      result.code
    end
  end
end
