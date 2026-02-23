require "rails_helper"

RSpec.describe "Users::Registrations", type: :request do
  describe "POST /users" do
    context "with valid params" do
      let(:valid_params) do
        {
          user: {
            name: "Jane Doe",
            email: "jane@example.com",
            password: "password123",
            password_confirmation: "password123"
          }
        }
      end

      it "redirects to the check_email page" do
        post user_registration_path, params: valid_params

        expect(response).to redirect_to(check_email_users_registrations_path(email: "jane@example.com"))
      end
    end
  end

  describe "GET /users/check_email" do
    it "returns 200 and displays the email" do
      get check_email_users_registrations_path, params: { email: "x@y.com" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("x@y.com")
    end
  end
end
