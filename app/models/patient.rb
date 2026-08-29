class Patient < ApplicationRecord
  belongs_to :clinic
  has_many :appointments, dependent: :destroy
  has_many :prescriptions, dependent: :destroy
  # Billing history outlives the patient record.
  has_many :visits, dependent: :nullify

  validates :name, :phone, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :age,
            numericality: {
              only_integer: true,
              greater_than: 0,
              less_than_or_equal_to: 130
            },
            allow_nil: true
end
