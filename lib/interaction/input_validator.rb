module Interaction
  InputError = Class.new(StandardError)

  module InputValidator
    class << self
      def included(base)
        base.extend ClassMethods
      end
    end

    module ClassMethods
      def require_input(*expected_inputs)
        @expected_inputs = expected_inputs
        prepend Validator
      end

      def expected_inputs
        @expected_inputs
      end
    end

    module Validator
      def call
        required_inputs = self.class.expected_inputs

        inputs_not_given = required_inputs - input.to_h.keys
        raise InputError, "#{inputs_not_given} missing from inputs" unless inputs_not_given.empty?

        inputs_with_nil_values = required_inputs.select do |i|
          input.to_h[i].nil? || (input.to_h[i].respond_to?(:empty?) && input.to_h[i].empty?)
        end
        raise InputError, "#{inputs_with_nil_values} was given blank input" unless inputs_with_nil_values.empty?

        super
      end
    end
  end
end
