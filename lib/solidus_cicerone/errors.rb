# frozen_string_literal: true

module SolidusCicerone
  class Error < StandardError
    attr_reader :status_code, :body

    def initialize(message = nil, status_code: nil, body: nil)
      @status_code = status_code
      @body = body
      super(message || "Cicerone request failed")
    end
  end

  class ConfigurationError < Error; end

  class RetryableError < Error; end
end
