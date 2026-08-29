class Doctor < ApplicationRecord
  belongs_to :clinic
  has_many :appointments, dependent: :destroy
  has_many :prescriptions, dependent: :destroy
  # Billing history outlives the doctor record.
  has_many :visits, dependent: :nullify

  validates :name, :specialty, :phone, :work_start, :work_end, presence: true

  validates :name, :specialty, :phone, presence: true

  validate :working_hours_are_valid

  private

  def working_hours_are_valid
    return if work_start.blank? || work_end.blank?
    return if work_end > work_start

    errors.add(:work_end, "must be after the start time")
  end
end
