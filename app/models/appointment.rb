class Appointment < ApplicationRecord
  belongs_to :clinic
  belongs_to :doctor
  belongs_to :patient

  # Billing ledger entry for this visit. Nullified rather than destroyed so a
  # deleted appointment cannot erase a visit the clinic already used.
  has_one :visit, dependent: :nullify

  STATUSES = ["pending", "confirmed", "completed", "cancelled"].freeze
  SOURCES  = ["clinic", "online"].freeze

  # The status that turns an appointment into one billable patient visit.
  BILLABLE_STATUS = "completed".freeze

  validates :appointment_date, :appointment_time, :status, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :source, inclusion: { in: SOURCES }

  scope :online,  -> { where(source: "online") }
  scope :pending, -> { where(status: "pending") }

  def online?
    source == "online"
  end

  validate :doctor_and_patient_belong_to_clinic
  validate :doctor_availability

  validate :appointment_within_doctor_working_hours

  # Billing runs after the appointment is safely committed, so a billing problem
  # can never roll back or block clinical work.
  after_commit :sync_billable_visit, on: [:create, :update]

  def billable_visit?
    status == BILLABLE_STATUS
  end

  private

  def sync_billable_visit
    return unless previously_new_record? || saved_change_to_status? || saved_change_to_appointment_date?

    VisitBillingService.sync_appointment(self)
  rescue StandardError => e
    Rails.logger.error("[VisitBilling] failed to sync appointment ##{id}: #{e.class}: #{e.message}")
  end

  def doctor_and_patient_belong_to_clinic
    return if clinic.blank?

    errors.add(:doctor, "must belong to your clinic") if doctor.present? && doctor.clinic_id != clinic_id
    errors.add(:patient, "must belong to your clinic") if patient.present? && patient.clinic_id != clinic_id
  end

  def doctor_availability
    return if clinic_id.blank? || doctor_id.blank? || appointment_date.blank? || appointment_time.blank?

    overlapping_appointments = clinic.appointments.where(
      doctor_id: doctor_id,
      appointment_date: appointment_date,
      appointment_time: appointment_time

    ).where.not(status: "cancelled"
    )

    overlapping_appointments = overlapping_appointments.where.not(id: id) if persisted?

    return unless overlapping_appointments.exists?


    errors.add(:appointment_time, :doctor_double_booked)
  end

  def appointment_within_doctor_working_hours
    return if doctor.blank? || appointment_time.blank?
    return if doctor.work_start.blank? || doctor.work_end.blank?

    appointment_seconds = appointment_time.seconds_since_midnight
    start_seconds = doctor.work_start.seconds_since_midnight
    end_seconds = doctor.work_end.seconds_since_midnight

    return if appointment_seconds >= start_seconds && appointment_seconds < end_seconds

    errors.add(:appointment_time, :outside_doctor_working_hours)
  end
end
