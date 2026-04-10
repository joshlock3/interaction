require "spec_helper"
require "interaction/base"

RSpec.describe Interaction::Hooks do
  describe "before_call" do
    it "runs a registered before_call method before the body" do
      order = []
      klass = Class.new(Interaction::Base) do
        before_call :log_start
        define_method(:call) { order << :body }
        define_method(:log_start) { order << :before }
      end

      klass.call
      expect(order).to eq([:before, :body])
    end

    it "runs multiple before_call hooks in declaration order" do
      order = []
      klass = Class.new(Interaction::Base) do
        before_call :a
        before_call :b

        define_method(:call) { order << :body }
        define_method(:a) { order << :a }
        define_method(:b) { order << :b }
      end

      klass.call
      expect(order).to eq([:a, :b, :body])
    end
  end

  describe "after_call" do
    it "runs after the body on success" do
      order = []
      klass = Class.new(Interaction::Base) do
        after_call :cleanup
        define_method(:call) { order << :body }
        define_method(:cleanup) { order << :after }
      end

      klass.call
      expect(order).to eq([:body, :after])
    end

    it "runs after the body on failure too" do
      after_ran = false
      klass = Class.new(Interaction::Base) do
        after_call :cleanup
        define_method(:call) { fail_with(error: "boom", code: :server_error) }
        define_method(:cleanup) { after_ran = true }
      end

      klass.call
      expect(after_ran).to eq(true)
    end

    it "can inspect result.failure? to opt out" do
      enqueued = false
      klass = Class.new(Interaction::Base) do
        after_call :enqueue_job
        define_method(:call) { fail_with(error: "no", code: :forbidden) }
        define_method(:enqueue_job) do
          next if result.failure?
          enqueued = true
        end
      end

      klass.call
      expect(enqueued).to eq(false)
    end
  end

  describe "inheritance" do
    it "subclasses inherit parent before_call and after_call hooks" do
      parent = Class.new(Interaction::Base) do
        before_call :p_before
        after_call :p_after
        define_method(:p_before) { nil }
        define_method(:p_after) { nil }
      end
      child = Class.new(parent) do
        before_call :c_before
        after_call :c_after
        define_method(:call) { result.details = {} }
        define_method(:c_before) { nil }
        define_method(:c_after) { nil }
      end

      expect(child.before_call_hooks).to eq([:p_before, :c_before])
      expect(child.after_call_hooks).to eq([:p_after, :c_after])
    end

    it "does not mutate parent's hook lists" do
      parent = Class.new(Interaction::Base) do
        before_call :p_before
        define_method(:p_before) { nil }
      end
      _child = Class.new(parent) do
        before_call :c_before
        define_method(:c_before) { nil }
      end

      expect(parent.before_call_hooks).to eq([:p_before])
    end
  end
end
