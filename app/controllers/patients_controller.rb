class PatientsController < ApplicationController
  before_action :ensure_clinic!
  before_action :set_patient, only: [:show, :edit, :update, :destroy, :history]
  before_action :check_patient_limit!, only: [:new, :create]

  def index
    @patients = current_clinic.patients.order(created_at: :desc)
  end

  def show
  end

  def new
    @patient = current_clinic.patients.new
  end

  def create
    @patient = current_clinic.patients.new(patient_params)
    if @patient.save
      redirect_to patients_path, notice: t("flash.patients.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @patient.update(patient_params)
      redirect_to patients_path, notice: t("flash.patients.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @patient.destroy
    redirect_to patients_path, notice: t("flash.patients.deleted")
  end

  def history
    @appointments = @patient.appointments.includes(:doctor).order(appointment_date: :desc, appointment_time: :desc)
    @prescriptions = @patient.prescriptions.includes(:doctor).order(prescription_date: :desc)
  end

  private

  def check_patient_limit!
    return if current_clinic.within_limit?(:patients)

    redirect_to patients_path,
      alert: t("flash.plan.limit_reached_patients",
               limit: current_clinic.patient_limit,
               plan:  current_clinic.plan_name)
  end

  def set_patient
    @patient = current_clinic.patients.find(params[:id])
  end

  def patient_params
    params.require(:patient).permit(:name, :phone, :age, :gender, :notes)
  end
end
