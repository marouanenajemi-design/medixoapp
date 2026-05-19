class Admin::ClinicsController < Admin::BaseController
  before_action :set_clinic, only: [:show, :destroy, :toggle_subscription, :extend_trial]

  def index
    @clinics = Clinic.includes(:user).order(created_at: :desc)
  end

  def show
    @doctors_count      = @clinic.doctors.count
    @patients_count     = @clinic.patients.count
    @appointments_count = @clinic.appointments.count
  end

  def toggle_subscription
    @clinic.update!(subscribed: !@clinic.subscribed?)
    status = @clinic.subscribed? ? t("admin.clinics.activated") : t("admin.clinics.deactivated")
    redirect_to admin_clinic_path(@clinic), notice: t("admin.clinics.subscription_updated", status: status)
  end

  def extend_trial
    current_end = @clinic.trial_ends_at.present? && @clinic.trial_ends_at.future? ? @clinic.trial_ends_at : Time.current
    @clinic.update!(trial_ends_at: current_end + 7.days)
    redirect_to admin_clinic_path(@clinic), notice: t("admin.clinics.trial_extended")
  end

  def destroy
    @clinic.destroy
    redirect_to admin_clinics_path, notice: t("admin.clinics.deleted", name: @clinic.name)
  end

  private

  def set_clinic
    @clinic = Clinic.find(params[:id])
  end
end
