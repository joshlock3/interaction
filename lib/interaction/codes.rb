# frozen_string_literal: true

module Interaction
  #
  # Conventional failure codes for Result#fail / Result#fail_with.
  #
  # These are *recommendations*, not enforced. Any symbol is accepted
  # as a failure code; these constants exist so callers can avoid typos
  # in the common cases and share a vocabulary across interactions.
  #
  # Usage:
  #
  #   result.fail(error: "Not allowed", code: Interaction::Codes::FORBIDDEN)
  #   result.fail(error: "Not allowed", code: :forbidden)  # equivalent
  #
  #   if result.failed_with?(:forbidden)
  #     render_forbidden
  #   end
  #
  module Codes
    INVALID_INPUT = :invalid_input
    UNAUTHORIZED = :unauthorized
    FORBIDDEN = :forbidden
    NOT_FOUND = :not_found
    CONFLICT = :conflict
    SERVER_ERROR = :server_error

    ALL = [
      INVALID_INPUT,
      UNAUTHORIZED,
      FORBIDDEN,
      NOT_FOUND,
      CONFLICT,
      SERVER_ERROR
    ].freeze
  end
end
