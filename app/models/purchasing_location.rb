class PurchasingLocation < ApplicationRecord
  COLOMBIAN_DEPARTMENTS = [
    "Amazonas",
    "Antioquia",
    "Arauca",
    "Atlántico",
    "Bolívar",
    "Boyacá",
    "Caldas",
    "Caquetá",
    "Casanare",
    "Cauca",
    "Cesar",
    "Chocó",
    "Córdoba",
    "Cundinamarca",
    "Guainía",
    "Guaviare",
    "Huila",
    "La Guajira",
    "Magdalena",
    "Meta",
    "Nariño",
    "Norte de Santander",
    "Putumayo",
    "Quindío",
    "Risaralda",
    "San Andrés y Providencia",
    "Santander",
    "Sucre",
    "Tolima",
    "Valle del Cauca",
    "Vaupés",
    "Vichada"
  ].freeze

  belongs_to :tenant
  has_many :buyer_profiles, dependent: :restrict_with_error
  has_many :buyers, through: :buyer_profiles, source: :user
  has_many :mineral_purchases, dependent: :nullify

  validates :name, :department, :city, :address, presence: true
  validates :department, inclusion: { in: COLOMBIAN_DEPARTMENTS }

  scope :kept, -> { where(deleted_at: nil) }

  def soft_delete!
    update!(deleted_at: Time.current)
  end
end
