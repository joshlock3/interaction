require "spec_helper"
require "interaction/codes"

RSpec.describe Interaction::Codes do
  it "defines conventional failure codes as symbols" do
    expect(described_class::INVALID_INPUT).to eq(:invalid_input)
    expect(described_class::UNAUTHORIZED).to eq(:unauthorized)
    expect(described_class::FORBIDDEN).to eq(:forbidden)
    expect(described_class::NOT_FOUND).to eq(:not_found)
    expect(described_class::CONFLICT).to eq(:conflict)
    expect(described_class::SERVER_ERROR).to eq(:server_error)
  end

  describe "ALL" do
    it "lists every defined code" do
      expect(described_class::ALL).to contain_exactly(
        :invalid_input, :unauthorized, :forbidden, :not_found, :conflict, :server_error
      )
    end

    it "is frozen" do
      expect(described_class::ALL).to be_frozen
    end
  end
end
