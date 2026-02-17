# frozen_string_literal: true

module Interaction
  class Configuration
    attr_accessor :on_error

    def initialize
      @on_error = ->(error, **kwargs) {}
    end
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end
  end
end
