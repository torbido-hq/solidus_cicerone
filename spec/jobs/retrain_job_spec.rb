# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidusCicerone::RetrainJob do
  it "POSTs the scheduler retrain hook" do
    stub_request(:post, "http://cicerone-trigger.test/trigger/retrain")
      .to_return(status: 202, body: { "status" => "started" }.to_json)

    described_class.perform_now

    expect(WebMock).to have_requested(:post, "http://cicerone-trigger.test/trigger/retrain")
  end
end
