module Interaction
  module InputDelegator
    class << self
      def included(base)
        base.extend ClassMethods
      end
    end

    InputError = Class.new(StandardError)

    module ClassMethods
      def delegate_input(*expected_inputs)
        expected_inputs.each do |expected_input|
          define_method(expected_input) do
            input.public_send(expected_input)
          end
        end
      end
    end
  end
end
