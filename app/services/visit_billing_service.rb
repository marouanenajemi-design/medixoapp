# Keeps the billable-visit ledger in sync with the appointment lifecycle.
#
# One completed appointment == exactly one billable visit:
#   * the ledger row is created the first time an appointment becomes "completed"
#   * if the appointment later leaves that status (cancelled, re-opened) the row
#     is voided, not deleted, so it stops counting but stays auditable
#   * if it becomes "completed" again the existing row is restored — never a
#     second one, so the same visit can never be charged twice
class VisitBillingService
  SOURCE = "appointment".freeze

  class << self
    # Entry point used by the Appointment after_commit callback.
    # amount_cents is the amount taken at the point of sale; nil means no amount
    # was supplied on this save, and the visit keeps whatever it already has.
    def sync_appointment(appointment, amount_cents: nil)
      return nil if appointment.blank?

      if appointment.billable_visit?
        record_appointment(appointment, amount_cents: amount_cents)
      else
        void_appointment(appointment)
      end
    end

    def record_appointment(appointment, amount_cents: nil)
      existing = Visit.find_by(appointment_id: appointment.id)
      return refresh(existing, appointment, amount_cents) if existing

      Visit.create!(visit_attributes(appointment, amount_cents))
    rescue ActiveRecord::RecordNotUnique
      # Two concurrent completions of the same appointment: the unique index on
      # visits.appointment_id decides, and we return the row that won.
      Visit.find_by(appointment_id: appointment.id)
    end

    def void_appointment(appointment)
      visit = Visit.billable.find_by(appointment_id: appointment.id)
      return nil if visit.blank?

      visit.void!
    end

    # Rebuilds the ledger from the appointments table. Idempotent — safe on
    # existing data and after any period where the callback failed.
    # Exposed as `rake billing:backfill_visits`.
    def backfill!(scope: Appointment.all)
      result = { created: 0, voided: 0, skipped: 0 }

      scope.find_each do |appointment|
        if appointment.billable_visit?
          if Visit.billable.exists?(appointment_id: appointment.id)
            result[:skipped] += 1
          else
            record_appointment(appointment)
            result[:created] += 1
          end
        elsif void_appointment(appointment)
          result[:voided] += 1
        end
      end

      result
    end

    private

    # A visit with no amount supplied falls back to the clinic's suggested
    # price, so non-interactive paths (backfill, seeds, a status change made
    # without the point-of-sale form) still produce a priced ledger row.
    def visit_attributes(appointment, amount_cents)
      {
        clinic_id:         appointment.clinic_id,
        appointment_id:    appointment.id,
        patient_id:        appointment.patient_id,
        doctor_id:         appointment.doctor_id,
        occurred_on:       occurred_on_for(appointment),
        source:            SOURCE,
        price_cents:       amount_cents || appointment.clinic.effective_price_per_visit_cents,
        amount_entered_at: amount_cents ? Time.current : nil,
        currency:          BillingSetting.current.currency
      }
    end

    # Keeps a re-completed or rescheduled appointment on one ledger row.
    #
    # The stored amount is only ever replaced by an explicit new amount from the
    # point of sale. A restore, a reschedule, or any configuration change leaves
    # the historical amount exactly as it was charged.
    def refresh(visit, appointment, amount_cents = nil)
      visit.assign_attributes(
        occurred_on: occurred_on_for(appointment),
        patient_id:  appointment.patient_id,
        doctor_id:   appointment.doctor_id,
        voided_at:   nil
      )

      if amount_cents
        visit.price_cents       = amount_cents
        visit.amount_entered_at = Time.current
      end

      visit.save! if visit.changed?
      visit
    end

    def occurred_on_for(appointment)
      appointment.appointment_date || appointment.created_at&.to_date || Date.current
    end
  end
end
