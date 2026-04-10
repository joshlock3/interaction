require "spec_helper"
require "interaction/input"
require "interaction/input_delegator"

RSpec.describe Interaction::InputDelegator do
  describe "A.4.1 regression: duplicate InputError constant" do
    it "does not define Interaction::InputDelegator::InputError" do
      expect(described_class.const_defined?(:InputError, false)).to eq(false)
    end
  end

  describe "delegate_input" do
    let(:klass) do
      Class.new do
        include Interaction::InputDelegator

        attr_reader :input

        def initialize(args)
          @input = Interaction::Input.new(args)
        end

        delegate_input :name, :age
      end
    end

    it "defines instance methods that delegate to input" do
      instance = klass.new(name: "Ada", age: 36)
      expect(instance.name).to eq("Ada")
      expect(instance.age).to eq(36)
    end
  end
end
