require "spec_helper"
require "interaction/base"

RSpec.describe Interaction::Enqueue do
  let(:job_class) do
    Class.new do
      class << self
        attr_accessor :last_call
      end
      def self.perform_now(*args, **kwargs)
        self.last_call = [:now, args, kwargs]
      end

      def self.perform_later(*args, **kwargs)
        self.last_call = [:later, args, kwargs]
      end
    end
  end

  let(:interaction_class) do
    local_job = job_class
    Class.new(Interaction::Base) do
      define_method(:call) do
        enqueue local_job, 1, 2
      end
    end
  end

  after do
    # reset to default
    Interaction.configuration.enqueue_synchronously = lambda {
      defined?(Rails) && Rails.respond_to?(:env) && Rails.env && (Rails.env.test? || Rails.env.development?)
    }
  end

  context "when configuration.enqueue_synchronously? is true" do
    before do
      Interaction.configuration.enqueue_synchronously = -> { true }
    end

    it "calls perform_now" do
      interaction_class.call
      expect(job_class.last_call[0]).to eq(:now)
      expect(job_class.last_call[1]).to eq([1, 2])
    end
  end

  context "when configuration.enqueue_synchronously? is false" do
    before do
      Interaction.configuration.enqueue_synchronously = -> { false }
    end

    it "calls perform_later" do
      interaction_class.call
      expect(job_class.last_call[0]).to eq(:later)
      expect(job_class.last_call[1]).to eq([1, 2])
    end
  end

  context "when configuration.enqueue_synchronously is set to a literal boolean" do
    it "accepts true" do
      Interaction.configuration.enqueue_synchronously = true
      interaction_class.call
      expect(job_class.last_call[0]).to eq(:now)
    end

    it "accepts false" do
      Interaction.configuration.enqueue_synchronously = false
      interaction_class.call
      expect(job_class.last_call[0]).to eq(:later)
    end
  end
end
