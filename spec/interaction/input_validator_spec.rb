require "spec_helper"
require "interaction/base"

RSpec.describe Interaction::InputValidator do
  let(:base_class) do
    Class.new(Interaction::Base) do
      def call
        result.details = {ok: true}
      end
    end
  end

  describe "A.4.5 regression: require_input appends across multiple calls" do
    it "records a single call" do
      base_class.require_input(:a, :b)
      expect(base_class.expected_inputs).to eq([:a, :b])
    end

    it "accumulates all required inputs across multiple calls (does not overwrite)" do
      base_class.require_input(:a, :b)
      base_class.require_input(:c)
      expect(base_class.expected_inputs).to eq([:a, :b, :c])
    end

    it "validates all accumulated inputs" do
      base_class.require_input(:a)
      base_class.require_input(:b)

      result = base_class.call(a: "x")
      expect(result.failure?).to eq(true)
      expect(result.error.to_s).to include("b")
      expect(result.error.to_s).to include("missing")
    end

    it "passes when all accumulated inputs are provided" do
      base_class.require_input(:a)
      base_class.require_input(:b)

      result = base_class.call(a: 1, b: 2)
      expect(result.success?).to eq(true)
    end
  end

  describe "expected_inputs default" do
    it "returns an empty array when require_input was never called" do
      expect(base_class.expected_inputs).to eq([])
    end
  end

  describe "A.4.4 regression: boolean and integer edge cases for blank detection" do
    before { base_class.require_input(:flag, :count) }

    it "treats false as a valid non-blank value" do
      result = base_class.call(flag: false, count: 0)
      expect(result.success?).to eq(true)
    end

    it "treats 0 as a valid non-blank value" do
      result = base_class.call(flag: true, count: 0)
      expect(result.success?).to eq(true)
    end
  end

  describe "inheritance" do
    it "subclasses do NOT inherit parent's expected_inputs (per v3.3 scope)" do
      base_class.require_input(:a)
      subclass = Class.new(base_class) do
        def call
          result.details = {}
        end
      end
      expect(subclass.expected_inputs).to eq([])
    end
  end
end
