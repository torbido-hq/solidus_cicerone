# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidusCicerone::Settings do
  it "writes through to configuration when no preference store exists" do
    described_class.set(serve_url: "http://admin.example", cache_ttl: 20)

    expect(SolidusCicerone.serve_url).to eq("http://admin.example")
    expect(SolidusCicerone.configuration.cache_ttl).to eq(20)
  end

  it "ignores unknown keys" do
    described_class.set(nope: "x")

    expect(SolidusCicerone.configuration.to_h).not_to have_key(:nope)
  end
end
