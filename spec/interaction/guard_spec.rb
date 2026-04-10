require "spec_helper"
require "interaction/base"

RSpec.describe Interaction::Guard do
  describe "guard declaration" do
    it "registers a guard method to run before call" do
      order = []
      klass = Class.new(Interaction::Base) do
        guard :first_guard

        define_method(:call) { order << :body }
        define_method(:first_guard) { order << :guard }
      end

      klass.call
      expect(order).to eq([:guard, :body])
    end

    it "runs multiple guards in declaration order" do
      order = []
      klass = Class.new(Interaction::Base) do
        guard :g1
        guard :g2
        guard :g3

        define_method(:call) { order << :body }
        define_method(:g1) { order << :g1 }
        define_method(:g2) { order << :g2 }
        define_method(:g3) { order << :g3 }
      end

      klass.call
      expect(order).to eq([:g1, :g2, :g3, :body])
    end

    it "halts at the first guard that fails, skipping remaining guards and body" do
      order = []
      klass = Class.new(Interaction::Base) do
        guard :g1
        guard :g2_halts
        guard :g3_never_runs

        define_method(:call) { order << :body }
        define_method(:g1) { order << :g1 }
        define_method(:g2_halts) do
          order << :g2_halts
          fail_with(error: "stop", code: :forbidden)
        end
        define_method(:g3_never_runs) { order << :g3_never_runs }
      end

      result = klass.call
      expect(order).to eq([:g1, :g2_halts])
      expect(result.failed_with?(:forbidden)).to eq(true)
      expect(result.error).to eq("stop")
    end
  end

  describe "guard + input DSL interaction" do
    it "guards run AFTER input validation (so inputs are guaranteed valid)" do
      guard_ran = false
      klass = Class.new(Interaction::Base) do
        input :name, String, required: true
        guard :check_name

        define_method(:call) { result.details = {ok: true} }
        define_method(:check_name) do
          guard_ran = true
          fail_with(error: "empty", code: :forbidden) if name.empty?
        end
      end

      result = klass.call
      expect(guard_ran).to eq(false)
      expect(result.failed_with?(:invalid_input)).to eq(true)
    end
  end

  describe "inheritance" do
    it "subclasses inherit parent guards" do
      parent = Class.new(Interaction::Base) do
        guard :parent_guard

        define_method(:parent_guard) { nil }
      end
      child = Class.new(parent) do
        guard :child_guard
        define_method(:call) { result.details = {} }
        define_method(:child_guard) { nil }
      end

      expect(child.declared_guards).to eq([:parent_guard, :child_guard])
    end

    it "parent's guard list is not mutated by the child" do
      parent = Class.new(Interaction::Base) do
        guard :parent_guard
        define_method(:parent_guard) { nil }
      end
      _child = Class.new(parent) do
        guard :child_guard
        define_method(:child_guard) { nil }
      end

      expect(parent.declared_guards).to eq([:parent_guard])
    end
  end
end
