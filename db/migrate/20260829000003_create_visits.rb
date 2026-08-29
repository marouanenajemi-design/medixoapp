class CreateVisits < ActiveRecord::Migration[7.1]
  def up
    create_table :visits do |t|
      t.references :clinic, null: false, foreign_key: true

      # A visit outlives the record that produced it: if the appointment (or the
      # patient/doctor) is deleted, the billing entry stays, with the link nulled.
      t.references :appointment, null: true, index: { unique: true },
                                 foreign_key: { on_delete: :nullify }
      t.references :patient, null: true, foreign_key: { on_delete: :nullify }
      t.references :doctor,  null: true, foreign_key: { on_delete: :nullify }

      t.date    :occurred_on, null: false
      t.string  :source,      null: false, default: "appointment"

      # Price in effect when the visit was recorded, kept for audit/invoicing.
      t.integer :price_cents, null: false, default: 0
      t.string  :currency,    null: false, default: "EUR"

      # Set when a recorded visit stops being billable (e.g. the appointment was
      # moved back out of "completed"). Voided rows are kept for the audit trail.
      t.datetime :voided_at

      # Hooks for a future payment/invoicing integration. Nothing writes these yet.
      t.datetime :invoiced_at
      t.string   :invoice_reference

      t.timestamps
    end

    add_index :visits, [:clinic_id, :occurred_on]
    add_index :visits, [:clinic_id, :voided_at]

    # Backfill: every already-completed appointment becomes one billable visit,
    # priced with the clinic override or the global default. ON CONFLICT keeps
    # this safe to re-run.
    execute <<~SQL
      INSERT INTO visits (clinic_id, appointment_id, patient_id, doctor_id,
                          occurred_on, source, price_cents, currency,
                          created_at, updated_at)
      SELECT a.clinic_id,
             a.id,
             a.patient_id,
             a.doctor_id,
             COALESCE(a.appointment_date, a.created_at::date),
             'appointment',
             COALESCE(c.price_per_visit_cents, bs.price_per_visit_cents, 200),
             COALESCE(bs.currency, 'EUR'),
             NOW(),
             NOW()
      FROM appointments a
      JOIN clinics c ON c.id = a.clinic_id
      LEFT JOIN billing_settings bs ON bs.singleton_guard = 0
      WHERE a.status = 'completed'
      ON CONFLICT (appointment_id) DO NOTHING;
    SQL
  end

  def down
    drop_table :visits
  end
end
