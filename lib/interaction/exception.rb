# frozen_string_literal: true

module Interaction
  module Exception
    class << self
      def report(error: nil, tags: nil, class_name: nil, context: nil)
        handler = Interaction.configuration.on_error
        kwargs = {tags: tags, class_name: class_name}
        # Handlers written for 3.x take only tags: and class_name:.
        kwargs[:context] = context if context && accepts_context?(handler)
        handler.call(error, **kwargs)
      end

      # A PII-free description of an interaction's inputs for error
      # reports: the input names, plus a reference for records
      # (`User(abc123)` / `User#42`) and only the class name for anything
      # else. Raw input values never leave the process.
      def context_for(interaction)
        inputs = interaction.input.to_h
        {
          class: interaction.class.name,
          input_keys: inputs.keys,
          inputs: inputs.transform_values { |value| summarize(value) }
        }
      end

      private

      def summarize(value)
        if value.nil? || value == true || value == false
          value
        elsif value.respond_to?(:public_id)
          "#{value.class.name}(#{value.public_id})"
        elsif value.class.respond_to?(:primary_key) && value.respond_to?(:id)
          "#{value.class.name}##{value.id}"
        else
          value.class.name
        end
      end

      def accepts_context?(handler)
        params = handler.respond_to?(:parameters) ? handler.parameters : handler.method(:call).parameters
        params.any? { |type, name| type == :keyrest || (%i[key keyreq].include?(type) && name == :context) }
      end
    end
  end
end
