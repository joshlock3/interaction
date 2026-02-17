module Interaction
  module Exception
    def self.report(error: nil, tags: nil, class_name: nil)
      Interaction.configuration.on_error.call(error, tags: tags, class_name: class_name)
    end
  end
end
