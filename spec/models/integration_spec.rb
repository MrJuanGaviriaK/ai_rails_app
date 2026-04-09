require "rails_helper"

RSpec.describe Integration, type: :model do
  it "assigns capabilities based on provider" do
    integration = build(:integration, provider: "dropbox_sign", capabilities: [])

    integration.valid?

    expect(integration.capabilities).to eq([ "e_signature" ])
  end

  it "masks credentials" do
    integration = build(:integration, credentials: { "api_key" => "1234567890" })

    expect(integration.masked_credentials["api_key"]).to eq("••••••567890")
  end
end
