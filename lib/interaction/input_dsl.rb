# frozen_string_literal: true

require_relative "coercion"
require_relative "codes"

module Interaction
  #
  # The `input` DSL — a single declarative form for declaring inputs,
  # their types, requirement, defaults, and coercion. Replaces both
  # `delegate_input` and `require_input` in new code.
  #
  # Usage:
  #
  #   class UpdateUser < Interaction::Base
  #     input :user_id,      String,  required: true
  #     input :username,     String,  required: false
  #     input :current_user, User,    required: true
  #     input :delete,       :boolean, default: false
  #     input :target_date,  :date,    required: false, coerce: true
  #
  #     def call
  #       # user_id, username, current_user, delete, target_date are
  #       # accessible as instance methods.
  #     end
  #   end
  #
  # Validation fires at the start of `#call` via a prepended module.
  # If any required input is missing or blank, the result fails with
  # `code: :invalid_input` before the body runs.
  #
  # Subclasses inherit their parent's input declarations via an
  # `inherited` callback.
  #
  module InputDsl
    class << self
      def included(base)
        base.extend ClassMethods
      end
    end

    Declaration = Struct.new(:name, :type, :required, :default, :coerce, keyword_init: true)

    module ClassMethods
      def input(name, type = nil, required: true, default: nil, coerce: false)
        input_declarations[name] = Declaration.new(
          name: name,
          type: type,
          required: required,
          default: default,
          coerce: coerce
        )

        define_method(name) do
          @_interaction_input_values ||= {}
          return @_interaction_input_values[name] if @_interaction_input_values.key?(name)

          decl = self.class.input_declarations[name]
          value = if input.to_h.key?(name)
            input.to_h[name]
          else
            _resolve_default(decl)
          end
          value = Coercion.coerce(value, decl.type) if decl.coerce && !value.nil?
          @_interaction_input_values[name] = value
        end
      end

      def input_declarations
        @input_declarations ||= {}
      end

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@input_declarations, input_declarations.dup)
      end
    end

    module InstanceMethods
      def call
        if (failure_message = _validate_declared_inputs)
          return result.fail_with(error: failure_message, code: Codes::INVALID_INPUT)
        end
        super
      end

      private

      def _validate_declared_inputs
        decls = self.class.input_declarations
        return nil if decls.empty?

        decls.each do |name, decl|
          # Invoke the accessor so defaults are resolved and cached once.
          value = send(name)
          next unless decl.required
          return "#{name} is required" if _blank_for_input?(value)
        end
        nil
      end

      def _blank_for_input?(value)
        return true if value.nil?
        return value.empty? if value.respond_to?(:empty?) && !(value == true || value == false)
        false
      end

      def _resolve_default(decl)
        decl.default.respond_to?(:call) ? decl.default.call : decl.default
      end
    end
  end
end
