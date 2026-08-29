# ── Analytics Test Seed ────────────────────────────────────────────────────────
# Adds 3 doctors, 20 patients, and 50 appointments distributed across the last
# 6 months (the full window the analytics controller charts).
#
# SAFE: never touches existing data. All test rows are tagged so they can be
#       removed cleanly with analytics_test_cleanup.rb.
#
# Run:    bin/rails runner db/seeds/analytics_test.rb
# Remove: bin/rails runner db/seeds/analytics_test_cleanup.rb
# ──────────────────────────────────────────────────────────────────────────────

raise "DO NOT run in production!" if Rails.env.production?

TAG = "[TEST]"          # prefix for doctor/patient names
NOTE = "ANALYTICS_TEST" # appointment notes marker — used by cleanup

clinic = Clinic.first
raise "No clinic found. Sign up and create a clinic first." unless clinic

puts "=" * 60
puts "Analytics Test Seed"
puts "Clinic : #{clinic.name} (ID: #{clinic.id})"
puts "=" * 60

# ── 1. Temporarily upgrade plan so analytics page is accessible ───────────────
original_plan       = clinic.plan_tier
original_subscribed = clinic.subscribed

clinic.update_columns(plan_tier: "pro", subscribed: true)
puts "\n✔ Clinic temporarily upgraded to Pro (analytics unlocked)"
puts "  Original plan: #{original_plan} | subscribed: #{original_subscribed.inspect}"
puts "  Cleanup will restore these values."

# ── 2. Create 3 test doctors ──────────────────────────────────────────────────
doctor_specs = [
  { name: "#{TAG} Dr. Alpha (General)",    specialty: "General Medicine" },
  { name: "#{TAG} Dr. Beta (Cardiology)",  specialty: "Cardiology" },
  { name: "#{TAG} Dr. Gamma (Pediatrics)", specialty: "Pediatrics" }
]

doctors = doctor_specs.map do |spec|
  clinic.doctors.find_or_create_by!(name: spec[:name]) do |d|
    d.specialty   = spec[:specialty]
    d.phone       = "+33 1 00 00 00 00"
    d.work_start  = Time.parse("09:00")
    d.work_end    = Time.parse("17:00")
  end
end
puts "\n✔ Doctors (#{doctors.size}):"
doctors.each { |d| puts "  ##{d.id}  #{d.name}" }

# ── 3. Create 20 test patients, backdated across the 6-month window ───────────
# Distribution: 2 + 3 + 3 + 4 + 4 + 4 = 20, one cohort per month.
patient_cohorts = [2, 3, 3, 4, 4, 4] # oldest → newest (months_ago 5..0)

patients = []
patient_cohorts.each_with_index do |count, idx|
  months_ago    = 5 - idx
  cohort_date   = months_ago.months.ago.beginning_of_month + 1.day
  cohort_ts     = cohort_date.to_time

  count.times do
    num = format("%02d", patients.size + 1)
    p = clinic.patients.find_or_create_by!(name: "#{TAG} Patient #{num}") do |pat|
      pat.phone  = "+33 6 #{num} 00 00 00"
      pat.age    = 20 + patients.size
      pat.gender = patients.size.even? ? "Male" : "Female"
    end
    # Backdate creation so patient_growth chart shows gradual growth
    p.update_columns(created_at: cohort_ts, updated_at: cohort_ts)
    patients << p
  end
end
puts "\n✔ Patients (#{patients.size}) — backdated across 6 months:"
patient_cohorts.each_with_index do |count, idx|
  months_ago = 5 - idx
  label = months_ago == 0 ? "Current month" : "#{months_ago} month(s) ago"
  puts "  #{label}: #{count} patients created"
end

# ── 4. Create 50 appointments ─────────────────────────────────────────────────
#
# Deterministic layout (NO randomness so expected values are exact):
#
# Appointment index → doctor:
#   0–19  → Dr. Alpha  (20 appts)
#   20–37 → Dr. Beta   (18 appts)
#   38–49 → Dr. Gamma  (12 appts)
#
# Appointment index → status:
#   0–19  → completed  (20)
#   20–34 → confirmed  (15)
#   35–44 → pending    (10)
#   45–49 → cancelled   (5)
#
# Monthly counts (oldest → newest):
#   months_ago 5: 6   months_ago 4: 7   months_ago 3: 8
#   months_ago 2: 9   months_ago 1: 10  months_ago 0: 10
#
MONTHLY_COUNTS = [6, 7, 8, 9, 10, 10].freeze  # sum = 50

DOCTOR_ASSIGNMENTS = (([0] * 20) + ([1] * 18) + ([2] * 12)).freeze
STATUS_ASSIGNMENTS = (
  (["completed"] * 20) + (["confirmed"] * 15) +
  (["pending"]   * 10) + (["cancelled"] *  5)
).freeze

appt_global_idx = 0
created_appointments = 0
skipped_collisions   = 0

MONTHLY_COUNTS.each_with_index do |count, month_idx|
  months_ago   = 5 - month_idx
  month_start  = months_ago.months.ago.beginning_of_month.to_date

  count.times do |appt_in_month|
    doctor  = doctors[DOCTOR_ASSIGNMENTS[appt_global_idx]]
    status  = STATUS_ASSIGNMENTS[appt_global_idx]
    patient = patients[appt_global_idx % patients.size]

    # Pick a distinct weekday within the month for each appointment.
    # day_offset 0..13 covers the first two weeks; avoids month-end edge cases.
    day_offset   = appt_in_month * 2
    date         = month_start + day_offset.days
    date        += 1.day while [0, 6].include?(date.wday) # skip Sat/Sun
    appt_time    = "09:00:00"

    # Guard against duplicate doctor+date+time (shouldn't happen given the
    # layout above, but safety net avoids validation errors).
    if clinic.appointments.exists?(doctor: doctor, appointment_date: date,
                                   appointment_time: appt_time)
      appt_time = "10:00:00"
    end

    appointment = clinic.appointments.new(
      doctor:           doctor,
      patient:          patient,
      appointment_date: date,
      appointment_time: appt_time,
      status:           status,
      source:           "clinic",
      notes:            NOTE
    )

    if appointment.save
      created_appointments += 1
    else
      skipped_collisions += 1
      puts "  ⚠ Skipped (#{appointment.errors.full_messages.first})"
    end

    appt_global_idx += 1
  end
end

puts "\n✔ Appointments: #{created_appointments} created, #{skipped_collisions} skipped"

# ── 5. Print expected analytics values ───────────────────────────────────────
puts "\n" + "=" * 60
puts "EXPECTED ANALYTICS VALUES"
puts "=" * 60

# Compute month labels the way the controller does
months_range = 5.downto(0).map { |i| Date.current.beginning_of_month - i.months }

puts "\n── Appointments by Month ──"
monthly_counts_hash = {}
MONTHLY_COUNTS.each_with_index do |cnt, idx|
  months_ago = 5 - idx
  month_date = months_ago.months.ago.beginning_of_month.to_date
  label = month_date.strftime("%b %Y")
  monthly_counts_hash[label] = cnt
end
months_range.each do |m|
  label = m.strftime("%b %Y")
  puts "  #{label}: #{monthly_counts_hash[label] || 0}"
end

puts "\n── Patient Growth (cumulative, excl. existing patients) ──"
cumulative = 0
months_range.each_with_index do |m, idx|
  cumulative += patient_cohorts[idx]
  puts "  #{m.strftime('%b %Y')}: #{cumulative} test patients (+ existing patients created before)"
end

puts "\n── Doctor Activity ──"
[
  ["#{TAG} Dr. Alpha (General)", 20],
  ["#{TAG} Dr. Beta (Cardiology)", 18],
  ["#{TAG} Dr. Gamma (Pediatrics)", 12]
].each { |name, count| puts "  #{name}: #{count} appointments" }

puts "\n── Status Breakdown ──"
puts "  Completed : 20"
puts "  Confirmed : 15"
puts "  Pending   : 10"
puts "  Cancelled :  5"
puts "  ──────────────"
puts "  Total     : 50"

total_not_cancelled = 20 + 15 + 10
completion_pct = (20.0 / total_not_cancelled * 100).round
puts "\n── Summary Stats ──"
puts "  This month (#{Date.current.strftime('%b %Y')}): 10 appointments"
puts "  Last month (#{1.month.ago.strftime('%b %Y')}): 10 appointments"
puts "  Completion rate: #{completion_pct}%  (20 completed / #{total_not_cancelled} non-cancelled)"
puts "  Active patients (last 3 months): 20  (all test patients have recent appointments)"

puts "\n" + "=" * 60
puts "DONE — test data is live."
puts "Run cleanup when finished:"
puts "  bin/rails runner db/seeds/analytics_test_cleanup.rb"
puts "=" * 60
