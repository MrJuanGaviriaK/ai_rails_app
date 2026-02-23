require "rails_helper"

RSpec.describe Users::Mailer, type: :mailer do
  describe "#confirmation_instructions" do
    let(:user) { create(:user, :unconfirmed) }
    let(:token) { user.confirmation_token }
    let(:mail) { described_class.confirmation_instructions(user, token) }

    before { user.send_confirmation_instructions }

    it "sends to the user's email address" do
      expect(mail.to).to eq([ user.email ])
    end

    it "sends from the configured address" do
      expect(mail.from).to include("noreply@mail.mrjg.dev")
    end

    it "includes the confirmation token in the body" do
      expect(mail.body.decoded).to include(token)
    end

    it "sets the List-Unsubscribe header" do
      expect(mail["List-Unsubscribe"].value).to include("unsubscribe@mail.mrjg.dev")
    end

    it "sets the List-Unsubscribe-Post header" do
      expect(mail["List-Unsubscribe-Post"].value).to eq("List-Unsubscribe=One-Click")
    end
  end
end
