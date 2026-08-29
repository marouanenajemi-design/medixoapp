# ── Analytics Test Cleanup ────────────────────────────────────────────────────
# Removes all rows created by analytics_test.rb and restores the clinic's
# original plan/subscription state.
#
# Run: bin/rails runner db/seeds/analytics_test_cleanup.rb
# ──────────────────────────────────────────────────────────────────────────────

raise "DO NOT run in production!" if Rails.env.production?

TAG  = "[TEST]"
NOTE = "ANALYTICS_TEST"

clinic = Clinic.first
raise "No clinic found." unless clinic

puts "=" * 60
puts "Analytics Test Cleanup"
puts "Clinic: #{clinic.name} (ID: #{clinic.id})"
puts "=" * 60

# ── 1. Delete test appointments (identified by their notes marker) ─────────────
appt_count = clinic.appointments.where(notes: NOTE).count
clinic.appointments.where(notes: NOTE).destroy_all
puts "\n✔ Deleted #{appt_count} test appointment(s)"

# ── 2. Delete test patients ───────────────────────────────────────────────────
patient_count = clinic.patients.where("name LIKE ?", "#{TAG}%").count
clinic.patients.where("name LIKE ?", "#{TAG}%").destroy_all
puts "✔ Deleted #{patient_count} test patient(s)"

# ── 3. Delete test doctors (cascade destroys their appointments automatically,
#       but the tagged appointments were already gone from step 1) ─────────────
doctor_count = clinic.doctors.where("name LIKE ?", "#{TAG}%").count
clinic.doctors.where("name LIKE ?", "#{TAG}%").destroy_all
puts "✔ Deleted #{doctor_count} test doctor(s)"

# ── 4. Restore original clinic plan ──────────────────────────────────────────
# Reverts to the state recorded before the seed ran (starter plan, unsubscribed,
# expired trial). Adjust these values if your clinic was already on a paid plan
# before running the seed.
clinic.update_columns(
  plan_tier:  "starter",
  subscribed: nil
)
puts "✔ Clinic plan restored to: starter (subscribed: nil)"

# ── 5. Summary ────────────────────────────────────────────────────────────────
puts "\n" + "=" * 60
puts "Cleanup complete."
puts "Remaining doctors  : #{clinic.doctors.count}"
puts "Remaining patients : #{clinic.patients.count}"
puts "Remaining appts    : #{clinic.appointments.count}"
puts "Current plan       : #{clinic.reload.plan_tier}"
puts "=" * 60
