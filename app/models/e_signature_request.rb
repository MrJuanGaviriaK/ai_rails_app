class ESignatureRequest < ApplicationRecord
  self.inheritance_column = :_type_disabled

  PROVIDERS = %w[dropbox_sign].freeze
  STATUSES = %w[draft sent awaiting_signature signed failed declined canceled expired].freeze

  belongs_to :tenant
  belongs_to :integration
  belongs_to :e_signature_template
  belongs_to :requestable, polymorphic: true
  belongs_to :initiated_by, class_name: "User", optional: true

  validates :provider, inclusion: { in: PROVIDERS }
  validates :status, inclusion: { in: STATUSES }

  scope :latest_first, -> { order(created_at: :desc) }

  def signed?
    status == "signed"
  end
end
