class Prescription < ApplicationRecord
  belongs_to :clinic
  belongs_to :doctor
  belongs_to :patient

  has_many :prescription_items, dependent: :destroy


  MEDICINE_ITEM_FIELDS = %w[medicine_name dosage frequency duration instructions].freeze

  accepts_nested_attributes_for :prescription_items,
                                allow_destroy: true,
                                reject_if: :medicine_item_blank?

  accepts_nested_attributes_for :prescription_items, allow_destroy: true, reject_if: :all_blank


  validates :prescription_date, presence: true

  validate :doctor_and_patient_belong_to_clinic


  before_validation :discard_blank_prescription_it

  private

  def doctor_and_patient_belong_to_clinic
    return if clinic.blank?

    errors.add(:doctor, "must belong to your clinic") if doctor.present? && doctor.clinic_id != clinic_id
    errors.add(:patient, "must belong to your clinic") if patient.present? && patient.clinic_id != clinic_id
  end


  def medicine_item_blank?(attributes)
    MEDICINE_ITEM_FIELDS.all? { |field| attributes[field].blank? }
  end

  def discard_blank_prescription_items
    prescription_items.each do |item|
      next if item.marked_for_destruction?
      next unless medicine_item_blank?(item.attributes)

      item.mark_for_destruction
    end
  end

end
