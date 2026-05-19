class ClinicsController < ApplicationController
  def new
    return redirect_to edit_clinic_path if current_clinic.present?

    @clinic = Clinic.new
  end

  def create
    return redirect_to edit_clinic_path, alert: t("flash.clinics.already_exists") if current_clinic.present?

    @clinic = current_user.build_clinic(clinic_params)
    @clinic.plan = "trial"
    @clinic.subscribed = false
    @clinic.trial_ends_at = 7.days.from_now

    if @clinic.save
      redirect_to dashboard_path, notice: "Clinic created successfully. Your 7-day free trial has started."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @clinic = current_clinic
    return redirect_to new_clinic_path, alert: t("flash.clinics.missing") unless @clinic
  end

  def update
    @clinic = current_clinic
    return redirect_to new_clinic_path, alert: t("flash.clinics.missing") unless @clinic

    if @clinic.update(clinic_params)
      redirect_to dashboard_path, notice: t("flash.clinics.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def clinic_params
    params.require(:clinic).permit(:name, :address, :phone, :logo)
  end
end
