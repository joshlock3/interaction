# frozen_string_literal: true

module Interaction
  class Configuration
    attr_accessor :on_error

    def initialize
      @on_error = ->(error, **kwargs) {
        class_name = kwargs[:class_name]
        tags = kwargs[:tags]
        formatted = "[#{class_name} Error] #{error.message}\n\n#{error.backtrace&.join("\n")}"

        if defined?(Sentry) && Sentry.respond_to?(:initialized?) && Sentry.initialized?
          Sentry.capture_exception(error, tags: tags)
        end

        if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
          Rails.logger.error(formatted)
        end

        warn(formatted)
      }
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
