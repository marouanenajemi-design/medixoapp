class Admin::PatientsController < Admin::BaseController
  def index
    @patients = Patient.includes(:clinic).order(created_at: :desc)
  end

  def show
    @patient = Patient.find(params[:id])
    @clinic  = @patient.clinic
  end
end
