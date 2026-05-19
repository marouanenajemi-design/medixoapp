class Admin::DashboardController < Admin::BaseController
  def index
    @total_users        = User.count
    @total_clinics      = Clinic.count
    @subscribed_clinics = Clinic.where(subscribed: true).count
    @trialing_clinics   = Clinic.where(subscribed: false).where("trial_ends_at > ?", Time.current).count
    @expired_clinics    = Clinic.where(subscribed: [false, nil])
                                .where("trial_ends_at IS NULL OR trial_ends_at <= ?", Time.current).count
    @total_doctors      = Doctor.count
    @total_patients     = Patient.count
    @total_appointments = Appointment.count

    @recent_users   = User.includes(:clinic).order(created_at: :desc).limit(6)
    @recent_clinics = Clinic.includes(:user).order(created_at: :desc).limit(6)
  end
end
