require "spec_helper"
require "interaction/input"

RSpec.describe Interaction::Input do
  let(:params) { { name: "Alice", age: 30 } }
  subject { described_class.new(params) }

  describe "#initialize" do
    it "accepts a hash" do
      expect(subject).to be_a(Interaction::Input)
    end

    it "accepts nil" do
      expect(described_class.new(nil)).to be_a(Interaction::Input)
    end
  end

  describe "#inputs_given?" do
    it "returns true when args are provided" do
      expect(subject.inputs_given?).to be true
    end

    it "returns false when args are empty" do
      expect(described_class.new({}).inputs_given?).to be false
    end

    it "returns false when args are nil" do
      expect(described_class.new(nil).inputs_given?).to be false
    end
  end

  describe "dynamic access" do
    it "allows access via dot notation" do
      expect(subject.name).to eq("Alice")
      expect(subject.age).to eq(30)
    end

    it "raises NoMethodError for missing keys" do
      expect { subject.unknown }.to raise_error(NoMethodError)
    end
    
    it "responds to known keys" do
        expect(subject.respond_to?(:name)).to be true
    end
    
    it "does not respond to unknown keys" do
        expect(subject.respond_to?(:unknown)).to be false
    end
  end

  describe "#to_h" do
    it "returns the underlying hash" do
      expect(subject.to_h).to eq(params)
    end
  end
end
