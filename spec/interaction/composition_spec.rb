require "spec_helper"
require "interaction/base"

RSpec.describe Interaction::Composition do
  before do
    stub_const("Greet", Class.new(Interaction::Base) do
      input :name, String, required: true

      def call
        result.details = {greeting: "Hi #{name}!"}
      end
    end)
  end

  describe "successful sub-interaction" do
    it "returns the sub-result's details hash" do
      parent = Class.new(Interaction::Base) do
        def call
          details = run Greet, name: "Alice"
          result.details = {echoed: details[:greeting]}
        end
      end

      result = parent.call
      expect(result.success?).to eq(true)
      expect(result.details[:echoed]).to eq("Hi Alice!")
    end

    it "allows chaining multiple sub-interactions" do
      parent = Class.new(Interaction::Base) do
        def call
          d1 = run Greet, name: "Alice"
          d2 = run Greet, name: "Bob"
          result.details = {greetings: [d1[:greeting], d2[:greeting]]}
        end
      end

      result = parent.call
      expect(result.details[:greetings]).to eq(["Hi Alice!", "Hi Bob!"])
    end
  end

  describe "failing sub-interaction" do
    it "propagates the sub-result's details into the parent and halts" do
      body_reached_line_after_run = false
      parent = Class.new(Interaction::Base) do
        define_method(:call) do
          run Greet  # missing required :name
          body_reached_line_after_run = true
          result.details = {never: "reached"}
        end
      end

      result = parent.call
      expect(body_reached_line_after_run).to eq(false)
      expect(result.failure?).to eq(true)
      expect(result.code).to eq(:invalid_input)
      expect(result.error).to include("name")
    end

    it "does not execute subsequent run statements after a failing sub" do
      second_ran = false
      parent = Class.new(Interaction::Base) do
        define_method(:call) do
          run Greet
          second_ran = true
          run Greet, name: "Alice"
        end
      end

      parent.call
      expect(second_ran).to eq(false)
    end
  end

  describe "nested composition" do
    it "propagates failure through multiple levels" do
      stub_const("Middle", Class.new(Interaction::Base) do
        def call
          run Greet  # missing :name, fails
        end
      end)

      outer = Class.new(Interaction::Base) do
        def call
          run Middle
        end
      end

      result = outer.call
      expect(result.failure?).to eq(true)
      expect(result.code).to eq(:invalid_input)
      expect(result.error).to include("name")
    end
  end
end
