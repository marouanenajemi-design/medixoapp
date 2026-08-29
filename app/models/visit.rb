# One billable patient visit.
#
# A visit is written to this ledger when an appointment reaches the "completed"
# status (see VisitBillingService). The unique index on appointment_id is what
# guarantees the same visit can never be charged twice; a visit that stops being
# billable is voided rather than deleted so the history stays auditable.
class Visit < ApplicationRecord
  belongs_to :clinic
  belongs_to :appointment, optional: true
  belongs_to :patient,     optional: true
  belongs_to :doctor,      optional: true

  SOURCES = %w[appointment manual].freeze

  validates :occurred_on, presence: true
  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :appointment_id, uniqueness: true, allow_nil: true

  validate :linked_records_belong_to_clinic

  scope :billable,      -> { where(voided_at: nil) }
  scope :voided,        -> { where.not(voided_at: nil) }
  scope :in_period,     ->(period) { where(occurred_on: period) }
  scope :uninvoiced,    -> { billable.where(invoiced_at: nil) }
  scope :chronological, -> { order(occurred_on: :desc, created_at: :desc) }

  # Billable visits × the clinic's effective price, for any scope of visits.
  # Used by the admin monetization dashboard.
  def self.usage_revenue_cents(scope = billable)
    counts = scope.group(:clinic_id).count
    return 0 if counts.empty?

    overrides    = Clinic.where(id: counts.keys).pluck(:id, :price_per_visit_cents).to_h
    default_cents = BillingSetting.current.price_per_visit_cents

    counts.sum { |clinic_id, count| count * (overrides[clinic_id] || default_cents) }
  end

  def billable?
    voided_at.nil?
  end

  def void!(at: Time.current)
    return self unless billable?

    update!(voided_at: at)
    self
  end

  def restore!
    return self if billable?

    update!(voided_at: nil)
    self
  end

  # Amount snapshotted when the visit was recorded, in currency units.
  def price
    price_cents.to_d / 100
  end

  private

  def linked_records_belong_to_clinic
    return if clinic_id.blank?

    errors.add(:appointment, "must belong to the same clinic") if appointment.present? && appointment.clinic_id != clinic_id
    errors.add(:patient, "must belong to the same clinic")     if patient.present?     && patient.clinic_id     != clinic_id
    errors.add(:doctor, "must belong to the same clinic")      if doctor.present?      && doctor.clinic_id      != clinic_id
  end
end
