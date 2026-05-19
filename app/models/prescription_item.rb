class PrescriptionItem < ApplicationRecord
  belongs_to :prescription

  validates :medicine_name, presence: true
end
