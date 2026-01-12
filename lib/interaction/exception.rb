module Interaction
  module Exception
    def self.report(error: nil, tags: nil, class_name: nil)
      error = %([#{class_name} Error] #{error}\n\n#{error.backtrace.join("\n")})
      Raven.capture_exception(error, tags: tags) if defined? Raven
      Rails.logger.error error if defined? Rails
    end
  end
end
