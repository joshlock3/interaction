# frozen_string_literal: true

require "rails/generators/base"

module Interaction
  module Generators
    class InteractionGenerator < Rails::Generators::NamedBase
      include Rails::Generators::ResourceHelpers

      source_root File.expand_path("../templates", __FILE__)
      class_option :inputs, type: :array, aliases: "-i", default: [], desc: "List of inputs to the interaction"

      desc "Generates a Interaction (Service Object) with the given NAME"

      def copy_initializer
        template "interaction.template", "app/interactions/#{name}.rb"
      end

      def copy_spects
        template "interaction_spec.template", "spec/interactions/#{name}_spec.rb"
      end
    end
  end
end
