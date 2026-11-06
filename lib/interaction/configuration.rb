# frozen_string_literal: true

module Interaction
  class Configuration
    DEFAULT_EXCEPTION_MESSAGE = "Something went wrong"

    # Maps an exception class to a failure code (see `rescue_from`).
    ExceptionMapping = Struct.new(:exception_class, :code, :message) do
      def message_for(error)
        case message
        when nil then error.message
        when String then message
        else message.call(error)
        end
      end
    end

    # on_error           — called with (error, tags:, class_name:, context:)
    #                      for unexpected exceptions. Handlers that don't
    #                      accept context: are called without it.
    # transaction        — callable taking a block; wraps `transactional`
    #                      interactions. Must open a real savepoint
    #                      (`requires_new: true`), or a nested halt or
    #                      failure won't roll its writes back.
    # after_commit       — callable taking a block; `enqueue` hands jobs
    #                      to it.
    # exception_message  — String, or callable taking the error; the
    #                      user-facing `error` for unexpected exceptions.
    # strict_inputs      — default for `input ..., strict:`.
    attr_accessor :on_error, :transaction, :after_commit, :exception_message, :strict_inputs
    attr_writer :enqueue_synchronously

    def initialize
      @on_error = ->(error, **kwargs) {
        class_name = kwargs[:class_name]
        formatted = "[#{class_name} Error] #{error.message}\n\n#{error.backtrace&.join("\n")}"

        if defined?(Sentry) && Sentry.respond_to?(:initialized?) && Sentry.initialized?
          Sentry.capture_exception(error, tags: kwargs[:tags], contexts: kwargs[:context] || {})
        end

        if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
          Rails.logger.error(formatted)
        end

        warn(formatted)
      }

      @enqueue_synchronously = lambda {
        defined?(Rails) && Rails.respond_to?(:env) && Rails.env && (Rails.env.test? || Rails.env.development?)
      }

      @transaction = lambda { |&block|
        if defined?(ActiveRecord::Base)
          ActiveRecord::Base.transaction(requires_new: true, &block)
        else
          block.call
        end
      }

      @after_commit = lambda { |&block|
        if defined?(ActiveRecord) && ActiveRecord.respond_to?(:after_all_transactions_commit)
          ActiveRecord.after_all_transactions_commit(&block)
        else
          block.call
        end
      }

      @exception_message = DEFAULT_EXCEPTION_MESSAGE
      @strict_inputs = false
      @exception_mappings = []
    end

    # Returns true when `enqueue` should run jobs synchronously
    # (perform_now) rather than enqueuing them (perform_later).
    # Accepts either a boolean or a callable in the setter.
    def enqueue_synchronously?
      callable = @enqueue_synchronously
      callable.respond_to?(:call) ? !!callable.call : !!callable
    end

    # Turn an exception raised from `#call` into an expected failure
    # instead of a reported :server_error.
    #
    #   config.rescue_from ActiveRecord::RecordInvalid, code: :invalid_input
    #   config.rescue_from ActiveRecord::RecordNotFound, code: :not_found, message: "Not found"
    #   config.rescue_from Stripe::CardError, code: :conflict, message: ->(e) { e.user_message }
    #
    # message: nil (default) uses error.message. Subclasses match; when
    # several mappings match, the last one declared wins. Mapped
    # exceptions are not passed to on_error.
    def rescue_from(exception_class, code:, message: nil)
      @exception_mappings << ExceptionMapping.new(exception_class, code, message)
      self
    end

    def exception_mapping_for(error)
      @exception_mappings.reverse_each.find { |mapping| error.is_a?(mapping.exception_class) }
    end

    def exception_message_for(error)
      msg = exception_message
      msg.respond_to?(:call) ? msg.call(error) : msg
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
