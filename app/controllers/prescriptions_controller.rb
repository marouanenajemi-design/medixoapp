class PrescriptionsController < ApplicationController
  before_action :ensure_clinic!
  before_action :set_prescription, only: [:show, :edit, :update, :destroy, :print]
  before_action :load_data, only: [:new, :create, :edit, :update]

  def index
    @prescriptions = current_clinic.prescriptions.includes(:doctor, :patient).order(created_at: :desc)
  end

  def show
  end

  def new
    @prescription = current_clinic.prescriptions.new
    @prescription.prescription_date = Date.current
    @prescription.prescription_items.build
  end

  def create
    @prescription = current_clinic.prescriptions.new(prescription_params)

    if @prescription.save
      redirect_to prescription_path(@prescription), notice: t("flash.prescriptions.created")
    else
      build_missing_items
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    build_missing_items
  end

  def update
    if @prescription.update(prescription_params)
      redirect_to prescription_path(@prescription), notice: t("flash.prescriptions.updated")
    else
      build_missing_items
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @prescription.destroy
    redirect_to prescriptions_path, notice: t("flash.prescriptions.deleted")
  end

  def print
    render layout: "print"
  end

  private

  def set_prescription
    @prescription = current_clinic.prescriptions.find(params[:id])
  end

  def load_data
    @doctors = current_clinic.doctors.order(:name)
    @patients = current_clinic.patients.order(:name)
  end

  def build_missing_items
    missing = 1 - @prescription.prescription_items.reject(&:marked_for_destruction?).size
    missing.times { @prescription.prescription_items.build } if missing.positive?
  end

  def prescription_params
    params.require(:prescription).permit(
      :prescription_date,
      :diagnosis,
      :notes,
      :doctor_id,
      :patient_id,
      prescription_items_attributes: [
        :id,
        :medicine_name,
        :dosage,
        :frequency,
        :duration,
        :instructions,
        :_destroy
      ]
    )
  end
end
