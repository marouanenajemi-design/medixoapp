class AnalyticsController < ApplicationController
  before_action :ensure_clinic!
  before_action :require_analytics_plan!

  def index
    @clinic = current_clinic

    @appointments_by_month = appointments_by_month_data
    @patient_growth        = patient_growth_data
    @doctor_activity       = doctor_activity_data
    @status_breakdown      = status_breakdown_data

    @total_this_month  = @clinic.appointments.where(appointment_date: Date.current.beginning_of_month..).count
    @total_last_month  = @clinic.appointments.where(
      appointment_date: 1.month.ago.beginning_of_month..1.month.ago.end_of_month
    ).count
    @completion_rate   = compute_completion_rate
    @active_patients   = @clinic.patients.joins(:appointments)
                                .where(appointments: { appointment_date: 3.months.ago.. })
                                .distinct.count
  end

  private

  def require_analytics_plan!
    return if current_clinic.plan_allows?(:analytics)

    redirect_to pricing_path,
      alert: t("flash.plan.analytics_required")
  end

  def months_range
    5.downto(0).map { |i| Date.current.beginning_of_month - i.months }
  end

  def appointments_by_month_data
    months_range.map do |month|
      count = @clinic.appointments
                     .where(appointment_date: month..month.end_of_month)
                     .count
      { label: month.strftime("%b %Y"), count: count }
    end
  end

  def patient_growth_data
    months_range.map do |month|
      count = @clinic.patients.where(created_at: ..month.end_of_month.end_of_day).count
      { label: month.strftime("%b %Y"), count: count }
    end
  end

  def doctor_activity_data
    @clinic.doctors
           .left_joins(:appointments)
           .group("doctors.id", "doctors.name")
           .select("doctors.name, COUNT(appointments.id) AS appointment_count")
           .order("appointment_count DESC")
           .map { |d| { name: d.name, count: d.appointment_count.to_i } }
  end

  def status_breakdown_data
    counts = @clinic.appointments.group(:status).count
    Appointment::STATUSES.map { |s| { status: s, count: counts[s].to_i } }
  end

  def compute_completion_rate
    total = @clinic.appointments.where.not(status: "cancelled").count
    return 0 if total.zero?

    completed = @clinic.appointments.where(status: "completed").count
    ((completed.to_f / total) * 100).round
  end
end
