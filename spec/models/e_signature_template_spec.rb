require "rails_helper"

RSpec.describe ESignatureTemplate, type: :model do
  it "is invalid when tenant does not match integration tenant" do
    integration = create(:integration)
    other_tenant = create(:tenant)
    template = build(:e_signature_template, integration: integration, tenant: other_tenant)

    expect(template).not_to be_valid
    expect(template.errors[:tenant_id]).to be_present
  end
end
