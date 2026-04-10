# frozen_string_literal: true

#
# Opt-in RSpec matchers for Interaction::Result.
#
# Add to your spec_helper.rb:
#
#   require "interaction/rspec"
#
# Usage:
#
#   expect(result).to be_a_successful_interaction
#   expect(result).to have_failed_with(:unauthorized)
#   expect(result).to have_failed_with("user not found")
#   expect(result).to have_interaction_details(goal: an_instance_of(Goal))
#
require "rspec/expectations"
require "interaction/result"

RSpec::Matchers.define :be_a_successful_interaction do
  match do |result|
    result.respond_to?(:success?) && result.success?
  end

  failure_message do |result|
    if result.respond_to?(:error)
      "expected a successful Interaction::Result, got failure: #{result.error.inspect}"
    else
      "expected an Interaction::Result, got #{result.inspect}"
    end
  end

  failure_message_when_negated do |result|
    details = result.respond_to?(:details) ? result.details : result
    "expected a failed Interaction::Result, got success with details #{details.inspect}"
  end
end

RSpec::Matchers.define :have_failed_with do |expected|
  match do |result|
    next false unless result.respond_to?(:failure?) && result.failure?

    if expected.is_a?(Symbol)
      result.respond_to?(:code) && result.code == expected
    else
      result.respond_to?(:error) && result.error.to_s.include?(expected.to_s)
    end
  end

  failure_message do |result|
    unless result.respond_to?(:failure?)
      next "expected an Interaction::Result, got #{result.inspect}"
    end

    unless result.failure?
      details = result.respond_to?(:details) ? result.details : nil
      next "expected failure, but Interaction::Result was successful with details #{details.inspect}"
    end

    if expected.is_a?(Symbol)
      actual_code = result.respond_to?(:code) ? result.code : nil
      actual_error = result.respond_to?(:error) ? result.error : nil
      "expected Interaction::Result to have failed with code #{expected.inspect}, got code #{actual_code.inspect} (error: #{actual_error.inspect})"
    else
      actual_error = result.respond_to?(:error) ? result.error : nil
      "expected Interaction::Result error to include #{expected.inspect}, got #{actual_error.inspect}"
    end
  end
end

RSpec::Matchers.define :have_interaction_details do |**expected|
  match do |result|
    next false unless result.respond_to?(:details)
    expected.all? { |k, v| values_match?(v, result.details[k]) }
  end

  failure_message do |result|
    actual = result.respond_to?(:details) ? result.details : result
    "expected Interaction::Result details to include #{expected.inspect}, got #{actual.inspect}"
  end
end
