# frozen_string_literal: true

require "ostruct"

module Interaction
  #
  # The Input object is responsible for ingesting parameters for the
  # interactor and converting hash keys to dot methods.
  #
  #
  # Example usage
  #   params = { greeting: "hello" }
  #   input = Input.new(params)
  #
  #   input.greeting => "hello"
  #   input.inputs_given? => true
  #   input.exceptions => [TypeError]
  #
  #
  class Input < OpenStruct
    def initialize(args = nil)
      @_has_args = !(args.nil? || args.size.zero?)
      super
    end

    def inputs_given?
      @_has_args
    end
  end
end
