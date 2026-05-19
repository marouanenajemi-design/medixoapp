class Admin::AppointmentsController < Admin::BaseController
  def index
    @appointments = Appointment.includes(:clinic, :doctor, :patient).order(appointment_date: :desc, appointment_time: :desc)
  end

  def show
    @appointment = Appointment.find(params[:id])
  end
end
