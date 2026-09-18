# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidusCicerone::Settings do
  it "writes through to configuration when no preference store exists" do
    described_class.set(serve_url: "http://admin.example", cache_ttl: 20)

    expect(SolidusCicerone.serve_url).to eq("http://admin.example")
    expect(SolidusCicerone.configuration.cache_ttl).to eq(20)
  end

  it "coerces enabled from admin string params" do
    described_class.set(enabled: "false")

    expect(SolidusCicerone.enabled?).to be(false)
  end

  it "ignores unknown keys" do
    described_class.set(nope: "x")

    expect(SolidusCicerone.configuration.to_h).not_to have_key(:nope)
  end

  it "reads and writes a preference store when Solidus is loaded" do
    store = Class.new do
      def initialize
        @hash = {}
      end

      def get(key)
        @hash[key]
      end

      def set(key, value)
        @hash[key] = value
      end
    end.new
    stub_const("Spree::Preferences::Store", Class.new { define_singleton_method(:instance) { store } })

    described_class.set(serve_url: "http://prefs.example")

    expect(described_class.get(:serve_url)).to eq("http://prefs.example")
  end

  it "swallows preference store errors" do
    store = Object.new
    def store.get(*)
      raise IOError, "boom"
    end

    def store.set(*)
      raise IOError, "boom"
    end
    stub_const("Spree::Preferences::Store", Class.new { define_singleton_method(:instance) { store } })

    expect(described_class.get(:serve_url)).to eq(SolidusCicerone.configuration.serve_url)
    expect { described_class.set(serve_url: "http://x") }.not_to raise_error
  end
end
