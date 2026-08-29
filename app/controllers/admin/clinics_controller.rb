class Admin::ClinicsController < Admin::BaseController
  before_action :set_clinic,
                only: [:show, :destroy, :toggle_subscription, :extend_trial, :update_plan, :update_visit_price]

  def index
    @clinics = Clinic.includes(:user).order(created_at: :desc)
  end

  def show
    @doctors_count      = @clinic.doctors.count
    @patients_count     = @clinic.patients.count
    @appointments_count = @clinic.appointments.count

    @billing_setting = BillingSetting.current
    @billing_summary = @clinic.billing_summary
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

  def update_plan
    new_tier = params[:plan_tier].to_s

    unless PlanGating::PLANS.key?(new_tier)
      redirect_to admin_clinic_path(@clinic), alert: t("admin.clinics.plan_tier.invalid")
      return
    end

    @clinic.update!(plan_tier: new_tier)
    redirect_to admin_clinic_path(@clinic),
      notice: t("admin.clinics.plan_tier.updated", plan: @clinic.plan_name)
  end

  # Per-clinic price-per-visit override. Submitting a blank price (or the reset
  # button) clears the override and puts the clinic back on the global price.
  def update_visit_price
    if params[:reset].present? || params[:price_per_visit].blank?
      @clinic.update!(price_per_visit_cents: nil)
      return redirect_to admin_clinic_path(@clinic), notice: t("admin.monetization.flash.override_cleared")
    end

    cents = BillingSetting.to_cents(params[:price_per_visit])

    if cents.nil?
      redirect_to admin_clinic_path(@clinic), alert: t("admin.monetization.flash.price_invalid")
      return
    end

    @clinic.update!(price_per_visit_cents: cents)
    redirect_to admin_clinic_path(@clinic),
      notice: t("admin.monetization.flash.override_updated",
                price: helpers.money(cents, @clinic.billing_currency))
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
