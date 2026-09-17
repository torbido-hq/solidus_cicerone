# frozen_string_literal: true

module SolidusCicerone
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end
