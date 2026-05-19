class Admin::DoctorsController < Admin::BaseController
  def index
    @doctors = Doctor.includes(:clinic).order(created_at: :desc)
  end

  def show
    @doctor = Doctor.find(params[:id])
    @clinic = @doctor.clinic
  end
end
