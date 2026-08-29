# Demo seed data for MedixoApp — generates realistic analytics charts.
# Safe to re-run: idempotent on the demo user/clinic/doctors.
# WARNING: clears all appointments and patients for the demo clinic on each run.

puts "Seeding MedixoApp demo data..."

# ── Demo user ──────────────────────────────────────────────────────────────────
demo_user = User.find_or_create_by!(email: "demo@medixoapp.com") do |u|
  u.password              = "Demo1234!"
  u.password_confirmation = "Demo1234!"
end

# ── Demo clinic (Pro plan) ─────────────────────────────────────────────────────
clinic = Clinic.find_or_initialize_by(user: demo_user)
clinic.assign_attributes(
  name:       "Green Valley Medical Center",
  address:    "14 Rue de la Santé, Paris 75014",
  phone:      "+33 1 42 34 56 78",
  plan_tier:  "pro",
  subscribed: true,
  plan:       "medixoapp-monthly"
)
clinic.save!

# ── Doctors ────────────────────────────────────────────────────────────────────
DOCTORS_CONFIG = [
  { name: "Dr. Sarah Mitchell",      specialty: "General Medicine", phone: "+33 1 11 22 33 44",
    work_start: "08:00", work_end: "18:00" },
  { name: "Dr. Jean-Pierre Martin",  specialty: "Cardiology",       phone: "+33 1 22 33 44 55",
    work_start: "09:00", work_end: "17:00" },
  { name: "Dr. Amina Benali",        specialty: "Pediatrics",        phone: "+33 1 33 44 55 66",
    work_start: "08:30", work_end: "16:30" },
  { name: "Dr. Thomas Weber",        specialty: "Orthopedics",       phone: "+33 1 44 55 66 77",
    work_start: "10:00", work_end: "19:00" },
].freeze

doctors = DOCTORS_CONFIG.map do |cfg|
  d = Doctor.find_or_initialize_by(clinic: clinic, name: cfg[:name])
  d.assign_attributes(
    specialty:  cfg[:specialty],
    phone:      cfg[:phone],
    work_start: Time.parse(cfg[:work_start]),
    work_end:   Time.parse(cfg[:work_end])
  )
  d.save!
  d
end

# ── Reset demo appointments, patients & billing ledger ─────────────────────────
# Visits survive appointment deletion by design (a clinic must not be able to
# erase usage it already had), so the demo ledger is cleared explicitly here —
# otherwise re-seeding would stack a fresh set of billable visits on the old one.
clinic.visits.delete_all
clinic.appointments.delete_all
clinic.patients.delete_all

# ── Patients (25, spread over 6 months to show growth curve) ──────────────────
PATIENT_NAMES = [
  "Marie Dubois",      "Ahmed Hassan",      "Sophie Laurent",
  "Carlos Mendez",     "Layla Al-Rashid",   "Pierre Fontaine",
  "Emma Johnson",      "Karim Benali",      "Isabelle Martin",
  "Mohammed Khalil",   "Claire Rousseau",   "David Chen",
  "Fatima Zahra",      "Lucas Petit",       "Natalie Schneider",
  "Omar Abdullah",     "Camille Bernard",   "Nicolas Leroy",
  "Yasmine Khoury",    "Antoine Moreau",    "Hana Yamamoto",
  "Roberto Silva",     "Elena Popescu",     "James O'Brien",
  "Aisha Diallo"
].freeze

PATIENT_AGES = [22, 34, 45, 28, 67, 52, 38, 41, 29, 55, 63, 31, 47, 25, 72,
                39, 44, 58, 33, 26, 49, 61, 37, 53, 42].freeze

GENDERS = %w[Female Male].freeze

# indices grouped by month offset (0 = current month, 5 = 5 months ago)
PATIENT_MONTH_MAP = {
  5 => [0, 1, 2, 3],
  4 => [4, 5, 6, 7],
  3 => [8, 9, 10, 11],
  2 => [12, 13, 14, 15, 16],
  1 => [17, 18, 19, 20, 21],
  0 => [22, 23, 24]
}.freeze

patients = []
PATIENT_MONTH_MAP.each do |months_ago, indices|
  indices.each_with_index do |idx, pos|
    created_at = Date.current.beginning_of_month - months_ago.months + (pos * 5).days
    p = Patient.create!(
      clinic: clinic,
      name:   PATIENT_NAMES[idx],
      phone:  "+33 1 #{format('%02d', 10 + idx)} #{format('%02d', 20 + idx)} #{format('%02d', 30 + idx)} #{format('%02d', 40 + idx)}",
      age:    PATIENT_AGES[idx],
      gender: GENDERS[idx % 2]
    )
    p.update_column(:created_at, created_at.to_time)
    patients << p
  end
end

# ── Appointments (100 total, growing month-over-month trend) ───────────────────
# Valid time slots per doctor index (guaranteed within working hours)
DOCTOR_SLOTS = [
  %w[09:00 10:00 11:00 14:00 15:00 16:00 17:00],  # Dr. Mitchell  08-18
  %w[09:30 10:30 11:30 14:30 15:30 16:00],          # Dr. Martin    09-17
  %w[09:00 10:00 11:00 13:30 14:30 15:30],           # Dr. Benali    08:30-16:30
  %w[10:30 11:30 14:00 15:00 16:00 17:00 18:00]     # Dr. Weber     10-19
].freeze

PAST_STATUSES   = %w[completed completed completed completed completed cancelled confirmed completed].freeze
FUTURE_STATUSES = %w[confirmed confirmed pending pending pending confirmed].freeze

# Growing appointment counts: Dec → May
APPTS_PER_MONTH = [10, 14, 18, 22, 24, 12].freeze

total_created = 0
patient_pool  = patients.dup

5.downto(0).each_with_index do |months_ago, m_idx|
  target_count = APPTS_PER_MONTH[m_idx]
  month_start  = Date.current.beginning_of_month - months_ago.months
  month_end    = months_ago == 0 ? Date.current - 1 : month_start.end_of_month

  # Build list of working days in this month window
  available_dates = (month_start..month_end).to_a.reject { |d| d.wday == 0 }  # exclude Sundays
  next if available_dates.empty?

  used_slots = Hash.new { |h, k| h[k] = [] }  # [doctor_idx, date] => [times_used]
  created    = 0

  target_count.times do |i|
    doctor_idx = i % doctors.size
    doctor     = doctors[doctor_idx]
    patient    = patient_pool.sample

    date = available_dates.sample
    key  = [doctor_idx, date]

    free_slots = DOCTOR_SLOTS[doctor_idx] - used_slots[key]
    next if free_slots.empty?

    time_str = free_slots.sample
    used_slots[key] << time_str

    is_past = date < Date.current
    status  = is_past ? PAST_STATUSES.sample : FUTURE_STATUSES.sample

    begin
      Appointment.create!(
        clinic:           clinic,
        doctor:           doctor,
        patient:          patient,
        appointment_date: date,
        appointment_time: Time.parse(time_str),
        status:           status
      )
      created       += 1
      total_created += 1
    rescue ActiveRecord::RecordInvalid
      # skip conflicts (working hours or double-booking edge cases)
    end
  end

  puts "  #{month_start.strftime('%b %Y')}: #{created}/#{target_count} appointments created"
end

puts ""
puts "✓ Demo clinic:   #{clinic.name} (#{clinic.plan_name} plan)"
puts "✓ Doctors:       #{doctors.size}"
puts "✓ Patients:      #{patients.size}"
puts "✓ Appointments:  #{total_created}"
puts ""
puts "Login: demo@medixoapp.com / Demo1234!"
