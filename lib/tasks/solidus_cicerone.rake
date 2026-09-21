# frozen_string_literal: true

namespace :solidus_cicerone do
  desc "Print Cicerone [input] SELECTs authored from ActiveRecord (paste on the Cicerone deploy)"
  task input: :environment do
    puts SolidusCicerone::Input.toml_fragment
  end
end
