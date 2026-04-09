require "rails_helper"

RSpec.describe "Admin::ESignatureTemplates", type: :request do
  let(:tenant) { create(:tenant) }
  let(:admin) do
    create(:user).tap { |user| user.add_role(:admin, tenant) }
  end
  let(:integration) { create(:integration, tenant: tenant) }

  before do
    sign_in_as(admin)
  end

  describe "GET /admin/e_signature_templates" do
    it "allows tenant admin users" do
      get admin_e_signature_templates_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /admin/e_signature_templates" do
    it "creates template when a PDF is attached" do
      file = fixture_file_upload("sample.pdf", "application/pdf")

      expect do
        post admin_e_signature_templates_path, params: {
          e_signature_template: {
            integration_id: integration.id,
            title: "NDA",
            message: "Please sign",
            active: "1",
            signer_roles_list: [ { name: "clinician" } ],
            custom_fields_list: [],
            metadata_json: "{}",
            document: file
          }
        }
      end.to change(ESignatureTemplate, :count).by(1)

      template = ESignatureTemplate.last
      expect(template.document).to be_attached
      expect(response).to redirect_to(builder_admin_e_signature_template_path(template))
    end

    it "rejects template when PDF is missing" do
      expect do
        post admin_e_signature_templates_path, params: {
          e_signature_template: {
            integration_id: integration.id,
            title: "NDA",
            message: "Please sign",
            active: "1"
          }
        }
      end.not_to change(ESignatureTemplate, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(I18n.t("admin.e_signature_templates.flash.fix_errors"))
    end

    it "rejects template when signer roles are missing" do
      file = fixture_file_upload("sample.pdf", "application/pdf")

      expect do
        post admin_e_signature_templates_path, params: {
          e_signature_template: {
            integration_id: integration.id,
            title: "NDA",
            message: "Please sign",
            active: "1",
            signer_roles_list: [ { name: "" } ],
            custom_fields_list: [],
            metadata_json: "{}",
            document: file
          }
        }
      end.not_to change(ESignatureTemplate, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(I18n.t("admin.e_signature_templates.errors.signer_roles_required"))
    end
  end

  describe "GET /admin/e_signature_templates/:id/builder" do
    let(:template) { create(:e_signature_template, integration: integration, tenant: tenant, provider_template_id: "remote_tpl_123") }

    it "renders the dedicated embedded builder page" do
      allow(ESignatureTemplates::BuildEmbeddedEditorSession).to receive(:call).with(template: template).and_return(
        {
          client_id: "client_id_123",
          edit_url: "https://app.hellosign.com/editor/embedded?token=abc",
          skip_domain_verification: true
        }
      )

      get builder_admin_e_signature_template_path(template)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("https://app.hellosign.com/editor/embedded?token=abc")
    end

    it "redirects to edit when Dropbox Sign returns an error" do
      allow(ESignatureTemplates::BuildEmbeddedEditorSession).to receive(:call).with(template: template)
        .and_raise(Integrations::DropboxSignClient::Error, "template is not editable")

      get builder_admin_e_signature_template_path(template)

      expect(response).to redirect_to(edit_admin_e_signature_template_path(template))
      follow_redirect!
      expect(response.body).to include("template is not editable")
    end
  end

  describe "GET /admin/e_signature_templates/:id/builder_saved" do
    let(:template) { create(:e_signature_template, integration: integration, tenant: tenant) }

    it "redirects to template list with success message" do
      get builder_saved_admin_e_signature_template_path(template)

      expect(response).to redirect_to(admin_e_signature_templates_path(integration_id: integration.id))
      follow_redirect!
      expect(response.body).to include(I18n.t("admin.e_signature_templates.flash.saved"))
    end
  end
end
