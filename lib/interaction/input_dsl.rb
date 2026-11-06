# frozen_string_literal: true

require_relative "coercion"
require_relative "codes"

module Interaction
  #
  # The `input` DSL — a single declarative form for declaring inputs,
  # their types, requirement, defaults, coercion and strictness. Replaces
  # `delegate_input` (deprecated) in new code.
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

    Declaration = Struct.new(:name, :type, :required, :default, :coerce, :strict, keyword_init: true)

    # Instance methods an input accessor would shadow, breaking the
    # interaction itself.
    RESERVED_NAMES = %i[
      call input result fail_with fail_from_exception handle_exception enqueue run_interaction
    ].freeze

    # Symbol types the strict check understands; :boolean is special-cased.
    STRICT_SYMBOL_TYPES = {
      string: String,
      integer: Integer,
      float: Float,
      symbol: Symbol,
      date: Date,
      hash: Hash,
      array: Array
    }.freeze

    module ClassMethods
      # strict: true fails the interaction with :invalid_input when a
      # present value isn't of the declared type (checked after coercion).
      # Defaults to Interaction.configuration.strict_inputs. Types the
      # check doesn't understand (e.g. `[String]`) are never checked.
      def input(name, type = nil, required: true, default: nil, coerce: false, strict: nil)
        if RESERVED_NAMES.include?(name.to_sym)
          raise ArgumentError, "input :#{name} is reserved — it would shadow Interaction::Base##{name}"
        end

        input_declarations[name] = Declaration.new(
          name: name,
          type: type,
          required: required,
          default: default,
          coerce: coerce,
          strict: strict
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
          return "#{name} is required" if decl.required && _blank_for_input?(value)
          next if value.nil?

          if _strict_input?(decl) && !_matches_input_type?(value, decl.type)
            return "#{name} must be #{_describe_input_type(decl.type)}"
          end
        end
        nil
      end

      def _strict_input?(decl)
        decl.strict.nil? ? Interaction.configuration.strict_inputs : decl.strict
      end

      def _matches_input_type?(value, type)
        return value == true || value == false if type == :boolean
        klass = type.is_a?(Module) ? type : STRICT_SYMBOL_TYPES[type]
        klass.nil? || value.is_a?(klass)
      end

      def _describe_input_type(type)
        return "a boolean" if type == :boolean
        klass = type.is_a?(Module) ? type : STRICT_SYMBOL_TYPES[type]
        article = /\A[AEIOU]/.match?(klass.name) ? "an" : "a"
        "#{article} #{klass.name}"
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
