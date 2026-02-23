require "rails_helper"

RSpec.describe UserMailer, type: :mailer do
  describe "#welcome_email" do
    let(:user) { build_stubbed(:user, name: "Alice", email: "alice@example.com") }
    let(:mail) { described_class.welcome_email(user) }

    it "sends to the user's email address" do
      expect(mail.to).to eq([ "alice@example.com" ])
    end

    it "sends from the configured address" do
      expect(mail.from).to include("noreply@mail.mrjg.dev")
    end

    it "sets the correct subject" do
      expect(mail.subject).to eq("Welcome to MRJG tools, Alice!")
    end

    it "includes the user's name in the HTML body" do
      expect(mail.html_part.body.decoded).to include("Alice")
    end

    it "includes the user's name in the text body" do
      expect(mail.text_part.body.decoded).to include("Alice")
    end

    it "includes a dashboard URL in the HTML body" do
      expect(mail.html_part.body.decoded).to include(dashboard_url)
    end

    it "includes a dashboard URL in the text body" do
      expect(mail.text_part.body.decoded).to include(dashboard_url)
    end

    it "includes the unsubscribe instruction in the text body" do
      expect(mail.text_part.body.decoded).to include("unsubscribe@mail.mrjg.dev")
    end

    it "sets the List-Unsubscribe header" do
      expect(mail["List-Unsubscribe"].value).to include("unsubscribe@mail.mrjg.dev")
    end

    it "sets the List-Unsubscribe-Post header" do
      expect(mail["List-Unsubscribe-Post"].value).to eq("List-Unsubscribe=One-Click")
    end

    it "is a multipart email (HTML + text)" do
      expect(mail.content_type).to match(%r{multipart/alternative})
    end
  end
end
