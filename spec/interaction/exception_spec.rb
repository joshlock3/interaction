require "rspec"
require "interaction/exception"

RSpec.describe Interaction::Exception do
  subject { Interaction::Exception }
  let(:arguments) do
    {
      error: StandardError.new("Something went terribly wrong").tap { |e| e.set_backtrace([]) },
      tags: [:production, :critical],
      class_name: "StandardClass"
    }
  end

  it { respond_to?(:report) }

  context "when Rails is defined" do
    let!(:rails) { double("Rails", logger: rails_logger) }
    let(:rails_logger) { double("logger", error: "") }

    before do
      stub_const("Rails", Object)
      allow(Rails).to receive(:logger).and_return(rails_logger)
    end

    it "invokes the Rails logger" do
      expect(Rails).to receive(:logger)
      subject.report(**arguments)
    end
  end

  context "when Raven is defined" do
    before do
      stub_const("Raven", Object)
      allow(Raven).to receive(:capture_exception)
    end

    it "invokes the Raven logger" do
      expect(Raven).to receive(:capture_exception)
      subject.report(**arguments)
    end
  end
end
