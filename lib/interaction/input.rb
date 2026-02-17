# frozen_string_literal: true

module Interaction
  class Input
    def initialize(args = {})
      @_args = args.to_h
    end

    def inputs_given?
      !@_args.empty?
    end

    def to_h
      @_args
    end

    def method_missing(method_name, *args, &block)
      if @_args.key?(method_name)
        @_args[method_name]
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      @_args.key?(method_name) || super
    end
  end
end
