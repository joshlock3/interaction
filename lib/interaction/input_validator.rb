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
        self.class_eval do
          @expected_inputs = expected_inputs
          original_method = instance_method(:call)

          define_method(:call) do
            required_inputs = self.class.expected_inputs

            inputs_not_given = required_inputs - @input.to_h.keys
            raise InputError, "#{inputs_not_given} missing from inputs" unless inputs_not_given.empty?

            inputs_with_nil_values = required_inputs.select do |i|
              @input.to_h[i].nil? || @input.to_h[i].size.zero?
            end
            raise InputError, "#{inputs_with_nil_values} was given blank input" unless inputs_with_nil_values.empty?

            original_method.bind(self).call
          end
        end

        # self.class_eval do
        #   original_method = instance_method(:initialize)
        #   define_method(:initialize) do |*args, &block|
        #     original_method.bind(self).call(*args, &block)
        #     inputs_not_given = self.class.expected_inputs - @input.to_h.keys
        #     raise InputError, "#{inputs_not_given} is missing from inputs" unless inputs_not_given.empty?
        #
        #     inputs_with_nil_values = self.class.expected_inputs.select { |i| @input.to_h[i].nil? }
        #     raise InputError, "#{inputs_with_nil_values} was given blank input" unless inputs_with_nil_values.empty?
        #   end
        # end
      end

      def expected_inputs
        @expected_inputs
      end
    end
  end
end
