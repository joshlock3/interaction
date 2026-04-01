require "rspec"
require "interaction/exception"

RSpec.describe Interaction::Exception do
  describe ".report" do
    let(:error) { StandardError.new("Boom") }
    let(:tags) { { tag: "value" } }
    let(:class_name) { "MyClass" }
    let(:error_handler) { spy("ErrorHandler") }

    before do
      allow(Interaction.configuration).to receive(:on_error).and_return(error_handler)
    end

    it "calls the configured error handler" do
      described_class.report(error: error, tags: tags, class_name: class_name)

      expect(error_handler).to have_received(:call).with(
        error,
        tags: tags,
        class_name: class_name
      )
    end
  end

  describe ".report with default configuration" do
    let(:error) { StandardError.new("Boom") }

    before do
      error.set_backtrace(["line1"])
      allow(Interaction).to receive(:configuration).and_call_original
    end

    it "writes to $stderr by default" do
      config = Interaction::Configuration.new
      allow(Interaction).to receive(:configuration).and_return(config)

      expect {
        described_class.report(error: error, tags: {}, class_name: "TestClass")
      }.to output(/\[TestClass Error\] Boom/).to_stderr
    end
  end
end
