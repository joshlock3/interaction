# frozen_string_literal: true

require "date"

module Interaction
  #
  # Small coercion helper for the `input` DSL. Supports a fixed set of
  # built-in types (Symbol or Class form). Unknown types pass through
  # unchanged. Failed coercions return the original value rather than
  # raising — validation errors surface through `required:` checks,
  # not coercion.
  #
  # Supported types:
  #   :string    or String  → value.to_s
  #   :integer   or Integer → Integer(value)
  #   :boolean              → true/false (accepts common string forms)
  #   :date      or Date    → Date.parse(value.to_s)
  #   :hash      or Hash    → value.to_h
  #   :array     or Array   → Array(value)
  #
  module Coercion
    module_function

    def coerce(value, type)
      if type == :string || type == ::String
        value.to_s
      elsif type == :integer || type == ::Integer
        Integer(value)
      elsif type == :boolean
        coerce_boolean(value)
      elsif type == :date || type == ::Date
        value.is_a?(::Date) ? value : ::Date.parse(value.to_s)
      elsif type == :hash || type == ::Hash
        value.is_a?(::Hash) ? value : value.to_h
      elsif type == :array || type == ::Array
        value.is_a?(::Array) ? value : Array(value)
      else
        value
      end
    rescue ArgumentError, TypeError
      # ArgumentError already covers Date::Error, which is a subclass.
      value
    end

    def coerce_boolean(value)
      return value if value == true || value == false
      downcased = value.to_s.downcase
      return true if %w[true 1 yes y].include?(downcased)
      return false if %w[false 0 no n].include?(downcased)
      !!value
    end
  end
end
