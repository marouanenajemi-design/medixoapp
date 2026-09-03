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

  # Revenue is the sum of the amounts actually charged at the point of sale.
  # Never count × a configured price: each visit carries its own amount.
  def self.usage_revenue_cents(scope = billable)
    scope.sum(:price_cents)
  end

  # [{ doctor_id:, visits:, revenue_cents: }] for any scope, richest first.
  # doctor_id may be nil (the doctor record was deleted after the visit).
  def self.revenue_by_doctor(scope = billable)
    scope.group(:doctor_id)
         .pluck(Arel.sql("doctor_id, COUNT(*), COALESCE(SUM(price_cents), 0)"))
         .map { |doctor_id, count, revenue| { doctor_id: doctor_id, visits: count, revenue_cents: revenue.to_i } }
         .sort_by { |row| -row[:revenue_cents] }
  end

  # [{ clinic_id:, visits:, revenue_cents: }] for any scope.
  def self.revenue_by_clinic(scope = billable)
    scope.group(:clinic_id)
         .pluck(Arel.sql("clinic_id, COUNT(*), COALESCE(SUM(price_cents), 0)"))
         .to_h { |clinic_id, count, revenue| [clinic_id, { visits: count, revenue_cents: revenue.to_i }] }
  end

  # True when a person typed this amount at the point of sale, rather than the
  # visit falling back to the suggested default price.
  def amount_entered?
    amount_entered_at.present?
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
