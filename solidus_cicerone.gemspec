# frozen_string_literal: true

require_relative "lib/solidus_cicerone/version"

Gem::Specification.new do |spec|
  spec.name = "solidus_cicerone"
  spec.version = SolidusCicerone::VERSION
  spec.authors = ["Nicholas Wieland"]
  spec.email = ["ngw@nofeed.org"]

  spec.summary = "Solidus host client for Cicerone."
  spec.description = <<~DESC
    Interprets Solidus with ActiveRecord. HTTP goes through the cicerone gem.
    Does not train or rank. Nightly training reads exported tables; storefront
    reads GET /recommendations; events dual-write to those tables and POST
    /events; impressions/clicks enqueue POST /track.
  DESC
  spec.homepage = "https://github.com/torbido-hq/solidus_cicerone"
  spec.license = "Beerware"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/releases"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.required_ruby_version = ">= 3.2"

  files = Dir.chdir(__dir__) do
    if File.directory?(".git")
      `git ls-files -z`.split("\x0")
    else
      Dir.glob("{app,config,db,lib}/**/*") + %w[LICENSE README.md CHANGELOG.md solidus_cicerone.gemspec]
    end
  end

  spec.files = files.grep_v(%r{^(test|spec|features)/})
  spec.bindir = "exe"
  spec.executables = files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "cicerone", "~> 0.1.0"
  spec.add_dependency "solidus_core", [">= 3.2", "< 5"]
  spec.add_dependency "solidus_support", [">= 0.12", "< 1"]

  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "solidus_dev_support", [">= 2.11", "< 3"]
  spec.add_development_dependency "webmock", "~> 3.24"
end
