# frozen_string_literal: true

module Integrations
  class DropboxSignConnectionTester
    Result = Struct.new(:success?, :account_id, :account_name, :error_message, keyword_init: true)

    def self.call(integration)
      new(integration).call
    end

    def initialize(integration)
      @integration = integration
    end

    def call
      account = Integrations::DropboxSignClient.new(@integration).fetch_account

      Result.new(
        success?: true,
        account_id: account["account_id"],
        account_name: account["email_address"] || account["account_id"]
      )
    rescue Integrations::DropboxSignClient::Error => e
      Result.new(success?: false, error_message: e.message)
    end
  end
end
