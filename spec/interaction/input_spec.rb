require 'rspec'
require 'interaction/input'

RSpec.describe Interaction::Input do
  let(:boolean) { [TrueClass, FalseClass] }
  subject { Interaction::Input.new }

  it { respond_to?(:capture_exception?) }
  it { respond_to?(:inputs_given?) }

  describe '#inputs_given?' do
    it 'returns a boolean' do
      expect(boolean).to include(subject.inputs_given?.class)
    end

    it 'returns false by default' do
      expect(subject.inputs_given?).to eq(false)
    end

    context 'when arguments are provided' do
      subject { Interaction::Input.new(input_arguments) }
      let(:input_arguments) do
        { greeting: "ciao!" }
      end

      it 'returns true' do
        expect(subject.inputs_given?).to eq(true)
      end
    end
  end

  context 'when arguments are given' do
    subject { Interaction::Input.new(input_arguments) }
    let(:input_arguments) do
      { greeting: "bonjour!" }
    end

    it 'returns the value of the key-pair argument' do
      expect(subject.greeting).to eq(input_arguments[:greeting])
    end
  end
end
