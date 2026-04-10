require "spec_helper"
require "interaction/base"

RSpec.describe Interaction::InputDsl do
  describe "input DSL" do
    let(:klass) do
      Class.new(Interaction::Base) do
        input :name, String, required: true
        input :age, Integer, required: false
        input :limit, Integer, default: 20
        input :flag, :boolean, default: false

        def call
          result.details = {name: name, age: age, limit: limit, flag: flag}
        end
      end
    end

    it "exposes declared inputs as instance methods" do
      result = klass.call(name: "Ada", age: 36)
      expect(result.success?).to eq(true)
      expect(result.details[:name]).to eq("Ada")
      expect(result.details[:age]).to eq(36)
    end

    it "applies default value when input is missing" do
      result = klass.call(name: "Ada")
      expect(result.details[:limit]).to eq(20)
      expect(result.details[:flag]).to eq(false)
    end

    it "uses the explicit value when provided (even if equal to default)" do
      result = klass.call(name: "Ada", limit: 50)
      expect(result.details[:limit]).to eq(50)
    end

    it "returns nil for optional inputs when not provided and no default" do
      result = klass.call(name: "Ada")
      expect(result.details[:age]).to be_nil
    end
  end

  describe "required validation" do
    let(:klass) do
      Class.new(Interaction::Base) do
        input :name, String, required: true
        def call
          result.details = {ok: true}
        end
      end
    end

    it "fails with :invalid_input code when a required input is missing" do
      result = klass.call
      expect(result.failure?).to eq(true)
      expect(result.code).to eq(:invalid_input)
      expect(result.error).to include("name")
    end

    it "fails with :invalid_input when a required input is nil" do
      result = klass.call(name: nil)
      expect(result.failed_with?(:invalid_input)).to eq(true)
    end

    it "fails with :invalid_input when a required input is empty string" do
      result = klass.call(name: "")
      expect(result.failed_with?(:invalid_input)).to eq(true)
    end

    it "does not run the body when required input is missing" do
      body_ran = false
      klass = Class.new(Interaction::Base) do
        input :x, String, required: true
        define_method(:call) {
          body_ran = true
          result.details = {}
        }
      end
      klass.call
      expect(body_ran).to eq(false)
    end

    it "treats false as a valid non-blank value" do
      klass = Class.new(Interaction::Base) do
        input :flag, :boolean, required: true
        def call
          result.details = {flag: flag}
        end
      end
      result = klass.call(flag: false)
      expect(result.success?).to eq(true)
      expect(result.details[:flag]).to eq(false)
    end

    it "treats 0 as a valid non-blank value" do
      klass = Class.new(Interaction::Base) do
        input :count, Integer, required: true
        def call
          result.details = {count: count}
        end
      end
      result = klass.call(count: 0)
      expect(result.success?).to eq(true)
      expect(result.details[:count]).to eq(0)
    end

    it "passes validation when default fills in a missing required input" do
      klass = Class.new(Interaction::Base) do
        input :limit, Integer, required: true, default: 10
        def call
          result.details = {limit: limit}
        end
      end
      result = klass.call
      expect(result.success?).to eq(true)
      expect(result.details[:limit]).to eq(10)
    end
  end

  describe "defaults" do
    it "supports value defaults" do
      klass = Class.new(Interaction::Base) do
        input :limit, Integer, default: 20
        def call
          result.details = {limit: limit}
        end
      end
      expect(klass.call.details[:limit]).to eq(20)
    end

    it "supports lambda defaults that are called per invocation" do
      counter = 0
      klass = Class.new(Interaction::Base) do
        input :tick, Integer, default: -> { counter += 1 }
        def call
          result.details = {tick: tick}
        end
      end
      expect(klass.call.details[:tick]).to eq(1)
      expect(klass.call.details[:tick]).to eq(2)
    end
  end

  describe "coercion" do
    it "coerces when coerce: true" do
      klass = Class.new(Interaction::Base) do
        input :count, Integer, required: true, coerce: true
        def call
          result.details = {count: count, class: count.class.name}
        end
      end
      result = klass.call(count: "42")
      expect(result.details[:count]).to eq(42)
      expect(result.details[:class]).to eq("Integer")
    end

    it "does not coerce when coerce: false (default)" do
      klass = Class.new(Interaction::Base) do
        input :count, Integer, required: true
        def call
          result.details = {count: count, class: count.class.name}
        end
      end
      result = klass.call(count: "42")
      expect(result.details[:count]).to eq("42")
      expect(result.details[:class]).to eq("String")
    end
  end

  describe "inheritance" do
    it "subclasses inherit parent input declarations" do
      parent = Class.new(Interaction::Base) do
        input :name, String, required: true
      end
      child = Class.new(parent) do
        input :age, Integer, required: false
        def call
          result.details = {name: name, age: age}
        end
      end

      expect(child.input_declarations.keys).to contain_exactly(:name, :age)
      result = child.call(name: "Ada", age: 36)
      expect(result.details).to eq({name: "Ada", age: 36})
    end

    it "subclass can override parent declaration" do
      parent = Class.new(Interaction::Base) do
        input :limit, Integer, default: 20
      end
      child = Class.new(parent) do
        input :limit, Integer, default: 50
        def call
          result.details = {limit: limit}
        end
      end

      expect(child.call.details[:limit]).to eq(50)
    end

    it "parent declarations are not mutated when child adds its own" do
      parent = Class.new(Interaction::Base) do
        input :name, String
      end
      _child = Class.new(parent) do
        input :age, Integer
      end
      expect(parent.input_declarations.keys).to contain_exactly(:name)
    end
  end
end
