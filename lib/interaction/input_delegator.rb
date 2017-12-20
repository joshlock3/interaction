require 'forwardable'

module Interaction
  module InputDelegator
    class << self
      def included(base)
        base.extend Forwardable
        base.extend ClassMethods
      end
    end

    InputError = Class.new(StandardError)

    module ClassMethods
      def delegate_input(*expected_inputs)
        self.def_delegators(:input, *(expected_inputs))
      end
    end
  end
end
