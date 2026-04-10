require "rspec"
require "interaction/result"

RSpec.describe Interaction::Result do
  let(:boolean) { [TrueClass, FalseClass] }
  subject { Interaction::Result.new }

  it { respond_to?(:success?) }
  it { respond_to?(:failure?) }
  it { respond_to?(:details) }
  it { respond_to?(:fail) }
  it { respond_to?(:fail_from_exception) }
  it { respond_to?(:custom_exception_detail) }

  describe "#failure?" do
    it "returns a boolean" do
      expect(boolean).to include(subject.failure?.class)
    end

    it "returns false by default" do
      expect(subject.failure?).to eq(false)
    end
  end

  describe "#success?" do
    it "returns a boolean" do
      expect(boolean).to include(subject.success?.class)
    end

    it "returns true by default" do
      expect(subject.success?).to eq(true)
    end

    it "returns the opposite of #failure?" do
      expect(subject.success? == !subject.failure?).to eq(true)
    end
  end

  describe "#fail" do
    it "changes the #success? from true to false" do
      expect { subject.fail }
        .to change { subject.success? }
        .from(true).to(false)
    end

    it "takes and sets details" do
      new_detail = {error_reason: "something went wrong"}
      subject.fail(new_detail)

      expect(subject.details).to include(new_detail)
    end
  end

  describe "#error" do
    it "returns error in details" do
      new_detail = {error: "something went wrong"}
      subject.fail(new_detail)

      expect(subject.error).to eq(new_detail[:error])
    end
  end

  describe "#fail_from_exception" do
    let(:exception_detail) do
      {exception_error: "something went horribly wrong"}
    end
    let(:normal_detail) do
      {action_error: "something went normally wrong"}
    end

    before { subject.custom_exception_detail = exception_detail }

    it "changes the #success? from true to false" do
      expect { subject.fail_from_exception(normal_detail) }
        .to change { subject.success? }
        .from(true).to(false)
    end

    it "takes and merges given details with exception details" do
      subject.fail_from_exception(normal_detail)

      expect(subject.details).to include(normal_detail)
      expect(subject.details).to include(exception_detail)
    end

    context "when neither caller nor custom_exception_detail supply :code" do
      subject { Interaction::Result.new }

      it "defaults :code to :server_error" do
        subject.fail_from_exception(error: "boom")
        expect(subject.code).to eq(:server_error)
        expect(subject.failed_with?(:server_error)).to eq(true)
      end
    end

    context "when caller supplies :code" do
      subject { Interaction::Result.new }

      it "caller code wins over :server_error default" do
        subject.fail_from_exception(error: "boom", code: :conflict)
        expect(subject.code).to eq(:conflict)
      end
    end

    context "when custom_exception_detail supplies :code" do
      subject { Interaction::Result.new }

      it "custom_exception_detail code wins over default" do
        subject.custom_exception_detail = {code: :invalid_input}
        subject.fail_from_exception(error: "boom")
        expect(subject.code).to eq(:invalid_input)
      end

      it "custom_exception_detail code wins even over caller-supplied :code" do
        subject.custom_exception_detail = {code: :invalid_input}
        subject.fail_from_exception(error: "boom", code: :conflict)
        expect(subject.code).to eq(:invalid_input)
      end
    end
  end

  describe "#code" do
    it "is nil on a fresh result" do
      expect(subject.code).to be_nil
    end

    it "is set by #fail when details includes :code" do
      subject.fail(error: "nope", code: :forbidden)
      expect(subject.code).to eq(:forbidden)
    end

    it "is set by #fail_with when :code is passed" do
      subject.fail_with(error: "nope", code: :not_found)
      expect(subject.code).to eq(:not_found)
    end

    it "stays nil when #fail is called without :code" do
      subject.fail(error: "nope")
      expect(subject.code).to be_nil
    end

    it "is still accessible via details[:code]" do
      subject.fail(error: "nope", code: :forbidden)
      expect(subject.details[:code]).to eq(:forbidden)
    end
  end

  describe "#failed_with?" do
    it "returns false on a successful result" do
      expect(subject.failed_with?(:forbidden)).to eq(false)
    end

    it "returns true when the result failed with the given code" do
      subject.fail(error: "x", code: :forbidden)
      expect(subject.failed_with?(:forbidden)).to eq(true)
    end

    it "returns false when the result failed with a different code" do
      subject.fail(error: "x", code: :forbidden)
      expect(subject.failed_with?(:not_found)).to eq(false)
    end

    it "returns false when the result failed with no code" do
      subject.fail(error: "x")
      expect(subject.failed_with?(:forbidden)).to eq(false)
    end
  end

  describe "#fail_with" do
    it "marks the result as failed" do
      expect { subject.fail_with(error: "boom") }
        .to change { subject.success? }
        .from(true).to(false)
    end

    it "merges attrs into existing details (does not replace)" do
      subject.details = {draft: "preserved"}
      subject.fail_with(error: "boom", code: :conflict)
      expect(subject.details).to include(draft: "preserved", error: "boom", code: :conflict)
    end

    it "sets #code from :code attr" do
      subject.fail_with(error: "x", code: :conflict)
      expect(subject.code).to eq(:conflict)
    end

    it "overrides an existing detail with the same key" do
      subject.details = {error: "original"}
      subject.fail_with(error: "updated")
      expect(subject.error).to eq("updated")
    end

    it "returns self for chaining or inspection" do
      expect(subject.fail_with(error: "x")).to eq(subject)
    end
  end
end
