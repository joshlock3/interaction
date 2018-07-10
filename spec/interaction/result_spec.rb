require 'rspec'
require 'interaction/result'

RSpec.describe Interaction::Result do
  let(:boolean) { [TrueClass, FalseClass] }
  subject { Interaction::Result.new }

  it { respond_to?(:success?) }
  it { respond_to?(:failure?) }
  it { respond_to?(:details) }
  it { respond_to?(:fail) }
  it { respond_to?(:fail_from_exception) }
  it { respond_to?(:custom_exception_detail) }

  describe '#failure?' do
    it 'returns a boolean' do
      expect(boolean).to include(subject.failure?.class)
    end

    it 'returns false by default' do
      expect(subject.failure?).to eq(false)
    end
  end

  describe '#success?' do
    it 'returns a boolean' do
      expect(boolean).to include(subject.success?.class)
    end

    it 'returns true by default' do
      expect(subject.success?).to eq(true)
    end

    it 'returns the opposite of #failure?' do
      expect(subject.success? == !subject.failure?).to eq(true)
    end
  end

  describe '#fail' do
    it 'changes the #success? from true to false' do
      expect { subject.fail }
        .to change { subject.success? }
        .from(true).to(false)
    end

    it 'takes and sets details' do
      new_detail = { error_reason: 'something went wrong' }
      subject.fail(new_detail)

      expect(subject.details).to include(new_detail)
    end
  end

  describe '#error' do
    it 'returns error in details' do
      new_detail = { error: 'something went wrong' }
      subject.fail(new_detail)

      expect(subject.error).to eq(new_detail[:error])
    end
  end

  describe '#fail_from_exception' do
    let(:exception_detail) do
      { exception_error: 'something went horribly wrong' }
    end
    let(:normal_detail) do
      { action_error: 'something went normally wrong' }
    end

    before { subject.custom_exception_detail = exception_detail }

    it 'changes the #success? from true to false' do
      expect { subject.fail_from_exception(normal_detail) }
        .to change { subject.success? }
        .from(true).to(false)
    end

    it 'takes and merges given details with exception details' do
      subject.fail_from_exception(normal_detail)

      expect(subject.details).to include(normal_detail)
      expect(subject.details).to include(exception_detail)
    end
  end
end
