require "rails_helper"

RSpec.describe User, type: :model do
  subject(:user) { build(:user) }

  describe "factory" do
    it "produces a valid user" do
      expect(user).to be_valid
    end
  end

  describe "validations" do
    # ---------------------------------------------------------------------------
    # name
    # ---------------------------------------------------------------------------
    context "when name is missing" do
      it "is invalid" do
        user.name = nil
        expect(user).not_to be_valid
        expect(user.errors[:name]).to include("can't be blank")
      end
    end

    context "when name is blank" do
      it "is invalid" do
        user.name = "   "
        expect(user).not_to be_valid
        expect(user.errors[:name]).to include("can't be blank")
      end
    end

    context "when name is present" do
      it "is valid" do
        user.name = "Alice"
        expect(user).to be_valid
      end
    end

    # ---------------------------------------------------------------------------
    # email — required and unique (Devise :validatable)
    # ---------------------------------------------------------------------------
    context "when email is missing" do
      it "is invalid" do
        user.email = nil
        expect(user).not_to be_valid
        expect(user.errors[:email]).not_to be_empty
      end
    end

    context "when email format is invalid" do
      it "is invalid" do
        user.email = "not-an-email"
        expect(user).not_to be_valid
        expect(user.errors[:email]).not_to be_empty
      end
    end

    context "when email is already taken" do
      it "is invalid" do
        create(:user, email: "taken@example.com")
        duplicate = build(:user, email: "taken@example.com")
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:email]).to include("has already been taken")
      end
    end

    context "when email is unique" do
      it "is valid" do
        user.email = "unique@example.com"
        expect(user).to be_valid
      end
    end

    # ---------------------------------------------------------------------------
    # password — required and minimum 6 chars (Devise :validatable default)
    # ---------------------------------------------------------------------------
    context "when password is missing" do
      it "is invalid on a new record" do
        user.password = nil
        user.password_confirmation = nil
        expect(user).not_to be_valid
        expect(user.errors[:password]).not_to be_empty
      end
    end

    context "when password is too short" do
      it "is invalid when fewer than 6 characters" do
        user.password = "abc"
        user.password_confirmation = "abc"
        expect(user).not_to be_valid
        expect(user.errors[:password]).not_to be_empty
      end
    end

    context "when password meets the minimum length" do
      it "is valid with exactly 6 characters" do
        user.password = "abcdef"
        user.password_confirmation = "abcdef"
        expect(user).to be_valid
      end
    end

    context "when password confirmation does not match" do
      it "is invalid" do
        user.password = "password123"
        user.password_confirmation = "different123"
        expect(user).not_to be_valid
        expect(user.errors[:password_confirmation]).not_to be_empty
      end
    end
  end

  describe "persistence" do
    it "persists a valid user to the database" do
      expect { create(:user) }.to change(described_class, :count).by(1)
    end

    it "does not persist an invalid user" do
      expect { create(:user, name: nil) }.to raise_error(ActiveRecord::RecordInvalid)
      expect(described_class.count).to eq(0)
    end
  end
end
