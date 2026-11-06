require "spec_helper"

# Specs for behaviour added in 4.0: transactional, Halt-based `run`,
# `call!`, rescue_from, the generic exception message, value-free error
# context, after-commit enqueue, strict and reserved inputs.
RSpec.describe "Interaction 4.0" do
  # A stand-in for ActiveRecord: records commits and rollbacks the way
  # ActiveRecord::Base.transaction does (any exception rolls back and
  # re-raises; after-commit blocks wait for the outermost commit).
  let(:fake_db) do
    Class.new do
      attr_reader :events

      def initialize
        @events = []
        @depth = 0
        @pending = []
      end

      def transaction
        @depth += 1
        yield
        @events << :commit
        if @depth == 1
          @pending.each(&:call)
          @pending.clear
        end
      rescue ::Exception # standard:disable Lint/RescueException
        @events << :rollback
        @pending.clear if @depth == 1
        raise
      ensure
        @depth -= 1
      end

      def after_commit(&block)
        @depth.zero? ? block.call : @pending << block
      end
    end.new
  end

  before do
    db = fake_db
    Interaction.configure do |config|
      config.transaction = ->(&block) { db.transaction(&block) }
      config.after_commit = ->(&block) { db.after_commit(&block) }
      config.on_error = ->(error, **) {}
    end
  end

  after { Interaction.instance_variable_set(:@configuration, nil) }

  describe "transactional" do
    it "is off by default and inherited when on" do
      parent = Class.new(Interaction::Base) { transactional }
      expect(Class.new(Interaction::Base).transactional?).to eq(false)
      expect(Class.new(parent).transactional?).to eq(true)
    end

    it "commits a successful call" do
      klass = Class.new(Interaction::Base) do
        transactional
        def call = result.details = {ok: true}
      end

      expect(klass.call).to be_success
      expect(fake_db.events).to eq([:commit])
    end

    it "fails with server_error when the transaction swallows a rollback" do
      rollback = Class.new(StandardError)
      Interaction.configuration.transaction = lambda do |&block|
        block.call
      rescue rollback # like ActiveRecord::Base.transaction with ActiveRecord::Rollback
        nil
      end
      klass = Class.new(Interaction::Base) do
        transactional
        define_method(:call) do
          result.details = {ok: true}
          raise rollback
        end
      end

      result = klass.call
      expect(result).to be_failure
      expect(result.failed_with?(:server_error)).to eq(true)
      expect(result.error).to eq("Transaction was rolled back")
    end

    it "rolls back when the result fails" do
      klass = Class.new(Interaction::Base) do
        transactional
        def call = fail_with(error: "nope", code: :conflict)
      end

      result = klass.call
      expect(result.failed_with?(:conflict)).to eq(true)
      expect(fake_db.events).to eq([:rollback])
    end

    it "rolls back on an exception and still reports a failure" do
      klass = Class.new(Interaction::Base) do
        transactional
        def call = raise("boom")
      end

      expect(klass.call.failed_with?(:server_error)).to eq(true)
      expect(fake_db.events).to eq([:rollback])
    end

    it "does not open a transaction when off" do
      Class.new(Interaction::Base) { def call = nil }.call
      expect(fake_db.events).to be_empty
    end
  end

  describe "run" do
    let(:failing) do
      Class.new(Interaction::Base) do
        def call = fail_with(error: "inner failed", code: :not_found)
      end
    end

    it "halts the caller, copies the failure and rolls back the transaction" do
      inner = failing
      outer = Class.new(Interaction::Base) do
        transactional
        define_method(:call) do
          run_interaction inner
          result.details = {reached: true}
        end
      end

      result = outer.call
      expect(result.failed_with?(:not_found)).to eq(true)
      expect(result.details).not_to include(:reached)
      expect(fake_db.events).to eq([:rollback])
    end

    it "is not swallowed by a bare rescue in the caller" do
      inner = failing
      outer = Class.new(Interaction::Base) do
        define_method(:call) do
          run inner
        rescue
          result.details = {swallowed: true}
        end
      end

      result = outer.call
      expect(result.error).to eq("inner failed")
      expect(result.details).not_to include(:swallowed)
    end
  end

  describe ".call!" do
    it "returns the result on success" do
      klass = Class.new(Interaction::Base) { def call = result.details = {ok: 1} }
      expect(klass.call!.details).to eq({ok: 1})
    end

    it "raises Interaction::Failure carrying the result" do
      klass = Class.new(Interaction::Base) { def call = fail_with(error: "bad", code: :forbidden) }

      expect { klass.call! }.to raise_error(Interaction::Failure) { |error|
        expect(error.message).to eq("bad")
        expect(error.code).to eq(:forbidden)
        expect(error.result).to be_failure
      }
    end

    it "propagates as an unreported failure when used inside another interaction" do
      reported = []
      Interaction.configuration.on_error = ->(error, **) { reported << error }
      inner = Class.new(Interaction::Base) { def call = fail_with(error: "inner", code: :conflict) }
      outer = Class.new(Interaction::Base) { define_method(:call) { inner.call! } }

      result = outer.call
      expect(result.failed_with?(:conflict)).to eq(true)
      expect(result.error).to eq("inner")
      expect(reported).to be_empty
    end
  end

  describe "unexpected exceptions" do
    let(:klass) do
      Class.new(Interaction::Base) do
        def self.name = "Things::Explode"
        def call = raise(ArgumentError, "secret detail: alice@example.com")
      end
    end

    it "fails with a generic message instead of the raw exception text" do
      result = klass.call(email: "alice@example.com")
      expect(result.error).to eq("Something went wrong")
      expect(result.code).to eq(:server_error)
    end

    it "accepts a custom exception_message" do
      Interaction.configuration.exception_message = ->(error) { "Oops (#{error.class})" }
      expect(klass.call.error).to eq("Oops (ArgumentError)")
    end

    it "reports PII-free context to handlers that accept it" do
      received = nil
      Interaction.configuration.on_error = ->(error, tags:, class_name:, context:) { received = context }
      record = Struct.new(:public_id).new("usr_123")

      klass.call(email: "alice@example.com", user: record, flag: true)

      inputs = received[:interaction][:inputs]
      expect(received[:interaction][:class]).to eq("Things::Explode")
      expect(received[:interaction][:input_keys]).to contain_exactly(:email, :user, :flag)
      expect(inputs[:email]).to eq("String")
      expect(inputs[:user]).to end_with("(usr_123)")
      expect(inputs[:flag]).to eq(true)
    end

    it "still calls 3.x handlers that take only tags: and class_name:" do
      received = nil
      Interaction.configuration.on_error = ->(error, tags:, class_name:) { received = class_name }
      klass.call
      expect(received).to eq("Things::Explode")
    end
  end

  describe "rescue_from" do
    let(:not_found) { Class.new(StandardError) }
    let(:klass) do
      error_class = not_found
      Class.new(Interaction::Base) { define_method(:call) { raise error_class, "Goal missing" } }
    end

    it "maps the exception to a code with its message and skips reporting" do
      reported = []
      Interaction.configuration.on_error = ->(error, **) { reported << error }
      Interaction.configuration.rescue_from(not_found, code: :not_found)

      result = klass.call
      expect(result.failed_with?(:not_found)).to eq(true)
      expect(result.error).to eq("Goal missing")
      expect(reported).to be_empty
    end

    it "supports a fixed or computed message" do
      Interaction.configuration.rescue_from(not_found, code: :not_found, message: "Not found")
      expect(klass.call.error).to eq("Not found")

      Interaction.configuration.rescue_from(not_found, code: :not_found, message: ->(e) { e.message.upcase })
      expect(klass.call.error).to eq("GOAL MISSING")
    end

    it "matches subclasses, with the last declared mapping winning" do
      Interaction.configuration.rescue_from(StandardError, code: :conflict)
      Interaction.configuration.rescue_from(not_found, code: :not_found)
      expect(klass.call.code).to eq(:not_found)
    end
  end

  describe "enqueue" do
    let(:job) do
      Class.new do
        class << self
          attr_accessor :calls
        end
        self.calls = []
        def self.perform_now(*args) = calls << args
      end
    end

    before { Interaction.configuration.enqueue_synchronously = true }

    it "defers the job until the transaction commits" do
      local_job = job
      log = fake_db.events
      klass = Class.new(Interaction::Base) do
        transactional
        define_method(:call) do
          enqueue local_job, 1
          log << :after_enqueue
        end
      end

      klass.call
      expect(job.calls).to eq([[1]])
      expect(fake_db.events).to eq([:after_enqueue, :commit])
    end

    it "drops the job when the transaction rolls back" do
      local_job = job
      klass = Class.new(Interaction::Base) do
        transactional
        define_method(:call) do
          enqueue local_job, 1
          fail_with(error: "nope")
        end
      end

      klass.call
      expect(job.calls).to be_empty
    end
  end

  describe "strict inputs" do
    let(:klass) do
      Class.new(Interaction::Base) do
        input :name, String, strict: true
        input :count, :integer, required: false, strict: true
        input :active, :boolean, required: false, strict: true
        input :tags, [String], required: false, strict: true
        def call = result.details = {ok: true}
      end
    end

    it "accepts values of the declared type" do
      expect(klass.call(name: "a", count: 1, active: false, tags: [1])).to be_success
    end

    it "fails with :invalid_input on a type mismatch" do
      result = klass.call(name: 42)
      expect(result.failed_with?(:invalid_input)).to eq(true)
      expect(result.error).to eq("name must be a String")

      expect(klass.call(name: "a", count: "1").error).to eq("count must be an Integer")
      expect(klass.call(name: "a", active: "yes").error).to eq("active must be a boolean")
    end

    it "checks after coercion" do
      coerced = Class.new(Interaction::Base) do
        input :count, :integer, coerce: true, strict: true
      end
      expect(coerced.call(count: "3")).to be_success
    end

    it "follows config.strict_inputs when strict: is not given" do
      lax = Class.new(Interaction::Base) { input :name, String }
      expect(lax.call(name: 42)).to be_success

      Interaction.configuration.strict_inputs = true
      expect(lax.call(name: 42)).to be_failure
    end
  end

  describe "reserved input names" do
    it "raises when an input would shadow an interaction method" do
      expect {
        Class.new(Interaction::Base) { input :result }
      }.to raise_error(ArgumentError, /reserved/)
    end
  end

  describe "Result#fail_from_exception" do
    it "keeps details set before the exception" do
      result = Interaction::Result.new
      result.details = {draft: :kept}
      result.fail_from_exception(error: "boom")
      expect(result.details).to include(draft: :kept, error: "boom", code: :server_error)
    end
  end
end
