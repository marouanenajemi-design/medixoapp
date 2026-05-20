class AppointmentsController < ApplicationController
  before_action :ensure_clinic!
  before_action :set_appointment, only: [:show, :edit, :update, :destroy, :approve, :reject]
  before_action :load_data, only: [:new, :create, :edit, :update]

  def index
    base = current_clinic.appointments.includes(:doctor, :patient)
    @online_pending = base.online.pending.order(appointment_date: :asc)
    @appointments   = base.order(appointment_date: :desc, appointment_time: :desc)
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

  def approve
    @appointment.update!(status: "confirmed")
    notify_patient_confirmed(@appointment)
    redirect_to appointments_path, notice: t("flash.appointments.approved",
      patient: @appointment.patient.name)
  end

  def reject
    @appointment.update!(status: "cancelled")
    notify_patient_rejected(@appointment)
    redirect_to appointments_path, notice: t("flash.appointments.rejected",
      patient: @appointment.patient.name)
  end

  private

  def set_appointment
    @appointment = current_clinic.appointments.find(params[:id])
  end

  def load_data
    @doctors  = current_clinic.doctors.order(:name)
    @patients = current_clinic.patients.order(:name)
  end

  def appointment_params
    params.require(:appointment).permit(:appointment_date, :appointment_time, :status, :notes, :doctor_id, :patient_id)
  end

  def notify_patient_confirmed(appointment)
    email = appointment.patient_email.presence || appointment.patient.email
    if email.blank?
      Rails.logger.warn("[AppointmentsController] approve: no patient_email for appointment ##{appointment.id}, skipping confirmation email")
      return
    end
    BookingMailer.patient_confirmed(appointment).deliver_later
  rescue StandardError => e
    Rails.logger.error("[AppointmentsController] patient_confirmed email failed for appointment ##{appointment.id}: #{e.class}: #{e.message}")
  end

  def notify_patient_rejected(appointment)
    email = appointment.patient_email.presence || appointment.patient.email
    if email.blank?
      Rails.logger.warn("[AppointmentsController] reject: no patient_email for appointment ##{appointment.id}, skipping rejection email")
      return
    end
    BookingMailer.patient_rejected(appointment).deliver_later
  rescue StandardError => e
    Rails.logger.error("[AppointmentsController] patient_rejected email failed for appointment ##{appointment.id}: #{e.class}: #{e.message}")
  end
end
