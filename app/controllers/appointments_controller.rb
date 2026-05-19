class AppointmentsController < ApplicationController
  before_action :ensure_clinic!
  before_action :set_appointment, only: [:show, :edit, :update, :destroy]
  before_action :load_data, only: [:new, :create, :edit, :update]

  def index
    @appointments = current_clinic.appointments.includes(:doctor, :patient).order(appointment_date: :desc, appointment_time: :desc)
  end

  def calendar
    @appointments = current_clinic.appointments.includes(:doctor, :patient)
  end

  def show
  end

  def new
    @appointment = current_clinic.appointments.new
    @appointment.appointment_date = params[:date] if params[:date].present?
  end

  def create
    @appointment = current_clinic.appointments.new(appointment_params)
    if @appointment.save
      redirect_to calendar_path, notice: t("flash.appointments.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @appointment.update(appointment_params)
      redirect_to calendar_path, notice: t("flash.appointments.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @appointment.destroy
    redirect_to appointments_path, notice: t("flash.appointments.deleted")
  end

  private

  def set_appointment
    @appointment = current_clinic.appointments.find(params[:id])
  end

  def load_data
    @doctors = current_clinic.doctors.order(:name)
    @patients = current_clinic.patients.order(:name)
  end

  def appointment_params
    params.require(:appointment).permit(:appointment_date, :appointment_time, :status, :notes, :doctor_id, :patient_id)
  end
end
