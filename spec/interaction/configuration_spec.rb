require "spec_helper"
require "interaction/configuration"

RSpec.describe Interaction::Configuration do
  describe "#on_error" do
    it "defaults to a proc" do
      expect(subject.on_error).to be_a(Proc)
    end

    it "can be set to a custom proc" do
      custom_proc = ->(e) {}
      subject.on_error = custom_proc
      expect(subject.on_error).to eq(custom_proc)
    end

    describe "default on_error behavior" do
      let(:error) { StandardError.new("something went wrong") }
      let(:kwargs) { {class_name: "TestInteraction", tags: {env: "test"}} }

      before do
        error.set_backtrace(["line1", "line2"])
      end

      it "writes to $stderr" do
        expect { subject.on_error.call(error, **kwargs) }.to output(
          /\[TestInteraction Error\] something went wrong/
        ).to_stderr
      end

      it "calls Sentry.capture_exception when Sentry is available" do
        sentry = double("Sentry", initialized?: true)
        stub_const("Sentry", sentry)
        allow(sentry).to receive(:respond_to?).with(:initialized?).and_return(true)
        expect(sentry).to receive(:capture_exception).with(error, tags: kwargs[:tags])
        subject.on_error.call(error, **kwargs)
      end

      it "does not call Sentry when it is not initialized" do
        sentry = double("Sentry", initialized?: false)
        stub_const("Sentry", sentry)
        allow(sentry).to receive(:respond_to?).with(:initialized?).and_return(true)
        expect(sentry).not_to receive(:capture_exception)
        subject.on_error.call(error, **kwargs)
      end

      it "calls Rails.logger.error when Rails is available" do
        logger = double("Logger")
        rails = double("Rails", logger: logger)
        stub_const("Rails", rails)
        allow(rails).to receive(:respond_to?).with(:logger).and_return(true)
        expect(logger).to receive(:error).with(/\[TestInteraction Error\] something went wrong/)
        subject.on_error.call(error, **kwargs)
      end
    end
  end

  describe "#enqueue_synchronously?" do
    it "defaults to a callable" do
      expect(subject.enqueue_synchronously?).to eq(false).or eq(true)
    end

    it "returns true when set to a literal true" do
      subject.enqueue_synchronously = true
      expect(subject.enqueue_synchronously?).to eq(true)
    end

    it "returns false when set to a literal false" do
      subject.enqueue_synchronously = false
      expect(subject.enqueue_synchronously?).to eq(false)
    end

    it "evaluates callables on each access" do
      toggle = true
      subject.enqueue_synchronously = -> { toggle }
      expect(subject.enqueue_synchronously?).to eq(true)
      toggle = false
      expect(subject.enqueue_synchronously?).to eq(false)
    end

    it "returns true when Rails.env is test" do
      rails = double("Rails", env: double("env", test?: true, development?: false))
      stub_const("Rails", rails)
      allow(rails).to receive(:respond_to?).with(:env).and_return(true)
      expect(subject.enqueue_synchronously?).to eq(true)
    end

    it "returns true when Rails.env is development" do
      rails = double("Rails", env: double("env", test?: false, development?: true))
      stub_const("Rails", rails)
      allow(rails).to receive(:respond_to?).with(:env).and_return(true)
      expect(subject.enqueue_synchronously?).to eq(true)
    end
  end

  describe "Interaction.configure" do
    it "yields the configuration" do
      expect {
        Interaction.configure do |config|
          expect(config).to be_a(Interaction::Configuration)
          raise "expected-from-configure-block"
        end
      }.to raise_error("expected-from-configure-block")
    end
  end
end
