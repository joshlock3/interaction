require "spec_helper"
require "interaction/configuration"

RSpec.describe Interaction::Configuration do
  describe "#on_error" do
    it "defaults to a no-op proc" do
      expect(subject.on_error).to be_a(Proc)
    end

    it "can be set to a custom proc" do
      custom_proc = ->(e) { }
      subject.on_error = custom_proc
      expect(subject.on_error).to eq(custom_proc)
    end
  end

  describe "Interaction.configure" do
    it "yields the configuration" do
      Expectation = Class.new(StandardError)
      expect {
        Interaction.configure do |config|
          expect(config).to be_a(Interaction::Configuration)
          raise Expectation
        end
      }.to raise_error(Expectation)
    end
  end
end
