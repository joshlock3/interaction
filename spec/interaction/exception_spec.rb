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
end
