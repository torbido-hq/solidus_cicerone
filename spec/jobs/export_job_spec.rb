# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidusCicerone::ExportJob do
  it "runs the exporter" do
    allow(SolidusCicerone::Exporter).to receive(:call)

    described_class.perform_now

    expect(SolidusCicerone::Exporter).to have_received(:call)
  end

  it "skips when disabled" do
    SolidusCicerone.configure { |c| c.enabled = false }
    allow(SolidusCicerone::Exporter).to receive(:call)

    described_class.perform_now

    expect(SolidusCicerone::Exporter).not_to have_received(:call)
  end
end
