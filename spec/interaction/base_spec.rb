require "rspec"
require "interaction/base"

RSpec.describe Interaction::Base do
  subject { Interaction::Base }

  it { respond_to?(:call) }

  describe "#call" do
    it "returns a Result Object" do
      expect(subject.call.class).to eq(Interaction::Result)
    end
  end

  context "when a class inherits from Base" do
    let(:test_interactor_class) do
      Class.new(Interaction::Base) do
        def call
          result.details = {greeting: "Hola!"}
        end
      end
    end

    let(:boolean) { [TrueClass, FalseClass] }
    subject { test_interactor_class.call }

    it "returns value of action taken in #call" do
      expect(subject.details).to eq({greeting: "Hola!"})
    end

    it "returns whether it has passed or failed" do
      expect(boolean).to include(subject.success?.class)
    end
  end
end
