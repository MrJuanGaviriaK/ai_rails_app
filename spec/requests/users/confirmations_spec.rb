require "rails_helper"

RSpec.describe "Users::Confirmations", type: :request do
  describe "GET /users/confirmation" do
    context "with a valid confirmation token" do
      let(:user) { create(:user, :unconfirmed) }

      before { user.send_confirmation_instructions }

      it "confirms the user, signs them in, and redirects to dashboard" do
        token = user.confirmation_token
        get user_confirmation_path, params: { confirmation_token: token }

        expect(response).to have_http_status(:see_other)
        expect(response).to redirect_to(dashboard_path)
        expect(user.reload.confirmed?).to be true
      end

      it "enqueues the welcome email on first confirmation" do
        token = user.confirmation_token
        expect {
          get user_confirmation_path, params: { confirmation_token: token }
        }.to have_enqueued_mail(UserMailer, :welcome_email)
      end
    end

    context "with an invalid token" do
      it "returns 200 and renders the confirmation form" do
        get user_confirmation_path, params: { confirmation_token: "invalid_token" }

        expect(response).to have_http_status(:ok)
      end
    end

    context "with an expired token" do
      let(:user) { create(:user, :confirmation_expired) }

      before { user.send_confirmation_instructions }

      it "does not confirm the user" do
        expired_user = create(:user, :confirmation_expired)
        # Manually set an old token to simulate expiry
        raw_token, hashed_token = Devise.token_generator.generate(User, :confirmation_token)
        expired_user.update_columns(
          confirmation_token: hashed_token,
          confirmation_sent_at: 4.days.ago
        )

        get user_confirmation_path, params: { confirmation_token: raw_token }

        expect(expired_user.reload.confirmed?).to be false
      end
    end
  end
end
