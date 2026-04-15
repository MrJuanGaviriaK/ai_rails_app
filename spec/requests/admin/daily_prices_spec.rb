require "rails_helper"

RSpec.describe "Admin::DailyPrices", type: :request do
  let(:tenant) { create(:tenant) }

  describe "GET /admin/daily_prices" do
    it "allows tenant admin users" do
      admin = create(:user)
      admin.add_role(:admin, tenant)
      sign_in_as(admin)

      get admin_daily_prices_path

      expect(response).to have_http_status(:ok)
    end

    it "blocks buyer users" do
      buyer = create(:user)
      buyer.add_role(:buyer, tenant)
      sign_in_as(buyer)

      get admin_daily_prices_path

      expect(response).to redirect_to(dashboard_path)
    end
  end

  describe "GET /admin/daily_prices/new" do
    it "renders mineral type as a select" do
      admin = create(:user)
      admin.add_role(:admin, tenant)
      sign_in_as(admin)

      get new_admin_daily_price_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to match(/<select[^>]*name="daily_price\[mineral_type\]"/)
      expect(response.body).to include(%(option value="oro"))
      expect(response.body).to include(%(option value="plata"))
      expect(response.body).to include(%(option value="platio"))
    end

    it "renders unit price with COP currency stimulus inputs" do
      admin = create(:user)
      admin.add_role(:admin, tenant)
      sign_in_as(admin)

      get new_admin_daily_price_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(data-controller="cop-currency-input"))
      expect(response.body).to include(%(data-cop-currency-input-target="display"))
      expect(response.body).to include(%(data-action="input->cop-currency-input#onInput"))
      expect(response.body).to include(%(type="hidden" name="daily_price[unit_price_cop]"))
      expect(response.body).to include(%(data-cop-currency-input-target="hidden"))
    end
  end

  describe "GET /admin/daily_prices/:id/edit" do
    it "keeps unit price in hidden field for stimulus formatting" do
      admin = create(:user)
      admin.add_role(:admin, tenant)
      sign_in_as(admin)
      daily_price = create(:daily_price, tenant:, mineral_type: "oro", unit_price_cop: 320_000.5)

      get edit_admin_daily_price_path(daily_price)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(data-controller="cop-currency-input"))
      expect(response.body).to include(%(name="daily_price[unit_price_cop]"))
      expect(response.body).to include(%(value="320000.5"))
    end
  end

  describe "POST /admin/daily_prices" do
    it "creates an approved daily price with actor audit" do
      admin = create(:user)
      admin.add_role(:admin, tenant)
      sign_in_as(admin)

      expect do
        post admin_daily_prices_path, params: {
          daily_price: {
            mineral_type: "oro",
            price_date: Date.current,
            unit_price_cop: "320000.50",
            state: "approved",
            notes: "Morning approved price"
          }
        }
      end.to change(DailyPrice, :count).by(1)

      daily_price = DailyPrice.last
      expect(response).to redirect_to(admin_daily_prices_path)
      expect(daily_price.created_by).to eq(admin)
      expect(daily_price.reviewed_by).to eq(admin)
      expect(daily_price.approved_at).to be_present
      expect(daily_price.state).to eq("approved")
    end

    it "rejects invalid mineral types" do
      admin = create(:user)
      admin.add_role(:admin, tenant)
      sign_in_as(admin)

      expect do
        post admin_daily_prices_path, params: {
          daily_price: {
            mineral_type: "palladium",
            price_date: Date.current,
            unit_price_cop: "320000.50",
            state: "pending"
          }
        }
      end.not_to change(DailyPrice, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("daily_price[mineral_type]")
    end
  end

  describe "PATCH /admin/daily_prices/:id" do
    it "rejects pending daily price and captures review audit" do
      admin = create(:user)
      admin.add_role(:admin, tenant)
      sign_in_as(admin)
      daily_price = create(:daily_price, tenant:, state: "pending", mineral_type: "plata")

      patch admin_daily_price_path(daily_price), params: {
        daily_price: {
          mineral_type: "plata",
          price_date: daily_price.price_date,
          unit_price_cop: "210000",
          state: "rejected",
          rejection_reason: "Validation mismatch"
        }
      }

      expect(response).to redirect_to(admin_daily_prices_path)
      expect(daily_price.reload.state).to eq("rejected")
      expect(daily_price.reviewed_by).to eq(admin)
      expect(daily_price.rejected_at).to be_present
      expect(daily_price.rejection_reason).to eq("Validation mismatch")
    end
  end
end
