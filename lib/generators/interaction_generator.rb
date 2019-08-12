# frozen_string_literal: true

require 'rails/generators/base'

module Interaction
  module Generators

    class InteractionGenerator < Rails::Generators::NamedBase
      include Rails::Generators::ResourceHelpers
      source_root File.expand_path('../templates', __FILE__)
      argument :interaction_name, type: :string
      class_option :inputs, type: :array, default: [], desc: "List of inputs to the interaction"

      desc "Generates a Interaction (Service Object) with the given NAME"

      def copy_initializer
        template "interaction.template", "app/interactions/#{interaction_name}.rb"
      end
    end
  end
end
