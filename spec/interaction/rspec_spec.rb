require "spec_helper"
require "interaction/rspec"
require "interaction/result"

RSpec.describe "Interaction RSpec matchers" do
  let(:result) { Interaction::Result.new }

  describe "be_a_successful_interaction" do
    it "matches a fresh successful result" do
      expect(result).to be_a_successful_interaction
    end

    it "does not match a failed result" do
      result.fail(error: "nope")
      expect(result).not_to be_a_successful_interaction
    end

    it "has a failure message mentioning the error" do
      result.fail(error: "boom")
      matcher = be_a_successful_interaction
      matcher.matches?(result)
      expect(matcher.failure_message).to include("boom")
    end
  end

  describe "have_failed_with" do
    context "with a Symbol (code match)" do
      it "matches when the result failed with the given code" do
        result.fail(error: "x", code: :forbidden)
        expect(result).to have_failed_with(:forbidden)
      end

      it "does not match when the code differs" do
        result.fail(error: "x", code: :not_found)
        expect(result).not_to have_failed_with(:forbidden)
      end

      it "does not match a successful result" do
        expect(result).not_to have_failed_with(:forbidden)
      end
    end

    context "with a String (error message substring match)" do
      it "matches when the error includes the substring" do
        result.fail(error: "User not found")
        expect(result).to have_failed_with("not found")
      end

      it "does not match when the substring is absent" do
        result.fail(error: "Something else")
        expect(result).not_to have_failed_with("not found")
      end
    end

    it "produces distinct failure messages for Symbol vs String expectations" do
      result.fail(error: "boom", code: :conflict)

      sym_matcher = have_failed_with(:forbidden)
      sym_matcher.matches?(result)
      expect(sym_matcher.failure_message).to match(/code/)

      str_matcher = have_failed_with("pineapple")
      str_matcher.matches?(result)
      expect(str_matcher.failure_message).to match(/include/)
    end
  end

  describe "have_interaction_details" do
    it "matches when all expected details are present" do
      result.details = {goal: "run 5k", user_id: 42}
      expect(result).to have_interaction_details(goal: "run 5k")
    end

    it "supports composable matchers like an_instance_of" do
      result.details = {count: 5}
      expect(result).to have_interaction_details(count: an_instance_of(Integer))
    end

    it "does not match when a key is missing or wrong" do
      result.details = {goal: "run 5k"}
      expect(result).not_to have_interaction_details(goal: "swim")
    end
  end
end
