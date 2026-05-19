class DashboardController < ApplicationController
  before_action :ensure_clinic!

  def index
    @clinic = current_clinic
    scoped_appointments = @clinic.appointments.includes(:doctor, :patient)

    @doctors_count = @clinic.doctors.count
    @patients_count = @clinic.patients.count
    @appointments_count = scoped_appointments.count
    @appointments_today = scoped_appointments.where(appointment_date: Date.current).count

    @recent_appointments = scoped_appointments.order(created_at: :desc).limit(5)
    @upcoming_appointments = scoped_appointments
      .where("appointment_date >= ?", Date.current)
      .where(status: %w[pending confirmed])
      .order(appointment_date: :asc, appointment_time: :asc)
      .limit(5)

    raw_status_counts = scoped_appointments.group(:status).count
    @status_breakdown = Appointment::STATUSES.index_with { |status| raw_status_counts[status].to_i }
  end
end
