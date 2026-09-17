# frozen_string_literal: true

module SolidusCicerone
  class ApplicationJob < ActiveJob::Base
    queue_as :default

    retry_on SolidusCicerone::RetryableError, wait: :polynomially_longer, attempts: 8
  end
end
