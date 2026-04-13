# frozen_string_literal: true

require "net/http"
require "stringio"

module Integrations
  class DropboxSignClient
    class Error < StandardError; end

    DEFAULT_BASE_URL = "https://api.hellosign.com/v3".freeze

    def initialize(integration)
      @integration = integration
      @api_key = integration.credentials["api_key"].to_s
      @client_id = integration.credentials["client_id"].to_s
      @base_url = integration.provider_config["api_base_url"].presence || DEFAULT_BASE_URL
    end

    attr_reader :client_id

    def fetch_account
      response = request(:get, "/account")
      response.fetch("account")
    end

    def list_templates
      response = request(:get, "/template/list")
      templates = response["templates"] || []

      templates.map do |template|
        {
          provider_template_id: template["template_id"],
          title: template["title"],
          message: template["message"],
          signer_roles: template["signer_roles"] || [],
          custom_fields: template["custom_fields"] || [],
          metadata: { "source" => "dropbox_sign_sync" },
          active: true,
          last_synced_at: Time.current
        }
      end
    end

    def create_embedded_template_draft(template:)
      raise Error, "Dropbox Sign client_id is missing" if client_id.blank?
      raise Error, "Template PDF is required to build embedded editor" unless template.document.attached?

      payload = []
      payload << [ "client_id", client_id ]
      payload << [ "title", template.title.to_s ]
      payload << [ "subject", template.title.to_s ]
      payload << [ "message", template.message.to_s ] if template.message.present?
      payload << [ "test_mode", test_mode? ? "1" : "0" ]

      signer_roles_payload(template.signer_roles).each_with_index do |role, index|
        payload << [ "signer_roles[#{index}][name]", role.fetch("name") ]
        payload << [ "signer_roles[#{index}][order]", role.fetch("order").to_s ]
      end

      merge_fields_payload(template.custom_fields).each_with_index do |field, index|
        payload << [ "merge_fields[#{index}][name]", field.fetch("name") ]
        payload << [ "merge_fields[#{index}][type]", field.fetch("type") ]
      end

      payload << [
        "files[0]",
        template.document.download,
        {
          filename: template.document.filename.to_s,
          content_type: template.document.content_type.presence || "application/pdf"
        }
      ]

      response = request(:post, "/template/create_embedded_draft", form_payload: payload)
      response.fetch("template")
    end

    def embedded_template_edit_url(template_id:, merge_fields: [])
      payload = {
        test_mode: test_mode?,
        merge_fields: merge_fields_payload(merge_fields)
      }

      response = request(:post, "/embedded/edit_url/#{template_id}", json_payload: payload)
      response.fetch("embedded")
    end

    def create_embedded_signature_request_with_template(template_id:, signer_name:, signer_email_address:, signer_role:, custom_fields: [])
      payload = {
        client_id:,
        template_ids: [ template_id ],
        subject: "Seller consent signature",
        message: "Please sign this consent.",
        signers: [
          {
            role: signer_role,
            name: signer_name,
            email_address: signer_email_address
          }
        ],
        custom_fields: custom_fields_payload(custom_fields),
        test_mode: test_mode?
      }

      request(:post, "/signature_request/create_embedded_with_template", json_payload: payload)
    end

    def create_signature_request_with_template(template_id:, signer_name:, signer_email_address:, signer_role:, custom_fields: [])
      payload = {
        template_ids: [ template_id ],
        subject: "Mineral purchase signature",
        message: "Please sign this document.",
        signers: [
          {
            role: signer_role,
            name: signer_name,
            email_address: signer_email_address
          }
        ],
        custom_fields: custom_fields_payload(custom_fields),
        test_mode: test_mode?
      }

      request(:post, "/signature_request/send_with_template", json_payload: payload)
    end

    def embedded_sign_url(signature_id:)
      response = request(:post, "/embedded/sign_url/#{signature_id}")
      response.fetch("embedded")
    end

    def download_signature_request_files(signature_request_id:)
      request_binary(:get, "/signature_request/files/#{signature_request_id}?file_type=pdf")
    end

    def test_mode?
      ActiveModel::Type::Boolean.new.cast(@integration.settings["test_mode"])
    end

    private

    def request(method, path, json_payload: nil, form_payload: nil)
      raise Error, "Dropbox Sign API key is missing" if @api_key.blank?

      uri = URI.parse("#{@base_url}#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.read_timeout = 15

      request = request_class(method).new(uri)
      request.basic_auth(@api_key, "")
      request["Accept"] = "application/json"

      if json_payload.present?
        request["Content-Type"] = "application/json"
        request.body = json_payload.to_json
      elsif form_payload.present?
        request.set_form(form_payload, "multipart/form-data")
      end

      response = http.request(request)

      parsed = JSON.parse(response.body.presence || "{}")
      return parsed if response.is_a?(Net::HTTPSuccess)

      message = parsed.dig("error", "error_msg") || parsed["error_msg"] || "Dropbox Sign API request failed"
      raise Error, message
    rescue JSON::ParserError
      raise Error, "Dropbox Sign API returned invalid JSON"
    rescue StandardError => e
      raise Error, e.message if e.is_a?(Error)

      raise Error, "Dropbox Sign request failed: #{e.message}"
    end

    def request_class(method)
      case method
      when :get then Net::HTTP::Get
      when :post then Net::HTTP::Post
      else
        raise ArgumentError, "Unsupported method: #{method}"
      end
    end

    def request_binary(method, path)
      raise Error, "Dropbox Sign API key is missing" if @api_key.blank?

      uri = URI.parse("#{@base_url}#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.read_timeout = 30

      request = request_class(method).new(uri)
      request.basic_auth(@api_key, "")
      request["Accept"] = "application/pdf"

      response = http.request(request)
      return response.body if response.is_a?(Net::HTTPSuccess)

      message = "Dropbox Sign API request failed"
      begin
        parsed = JSON.parse(response.body.presence || "{}")
        message = parsed.dig("error", "error_msg") || parsed["error_msg"] || message
      rescue JSON::ParserError
        message = "Dropbox Sign API returned invalid response"
      end

      raise Error, message
    rescue StandardError => e
      raise Error, e.message if e.is_a?(Error)

      raise Error, "Dropbox Sign request failed: #{e.message}"
    end

    def signer_roles_payload(roles)
      Array(roles).filter_map.with_index do |role, index|
        role = role.to_h if role.respond_to?(:to_h)
        next unless role.is_a?(Hash)

        name = (role["name"] || role[:name]).to_s.strip
        next if name.blank?

        {
          "name" => name,
          "order" => index
        }
      end
    end

    def merge_fields_payload(fields)
      Array(fields).filter_map do |field|
        field = field.to_h if field.respond_to?(:to_h)
        next unless field.is_a?(Hash)

        name = (field["name"] || field[:name] || field["api_id"] || field[:api_id]).to_s.strip
        next if name.blank?

        {
          "name" => name,
          "type" => normalize_merge_field_type(field["type"] || field[:type])
        }
      end.uniq { |field| field["name"] }
    end

    def normalize_merge_field_type(raw_type)
      type = raw_type.to_s.downcase
      return "checkbox" if type == "checkbox"

      "text"
    end

    def custom_fields_payload(fields)
      Array(fields).filter_map do |field|
        field = field.to_h if field.respond_to?(:to_h)
        next unless field.is_a?(Hash)

        name = (field["name"] || field[:name]).to_s.strip
        value = (field["value"] || field[:value]).to_s
        next if name.blank?

        {
          name:,
          value:
        }
      end
    end
  end
end
