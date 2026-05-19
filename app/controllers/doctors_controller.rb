class DoctorsController < ApplicationController
  before_action :ensure_clinic!
  before_action :set_doctor, only: [:show, :edit, :update, :destroy]

  def index
    @doctors = current_clinic.doctors.order(created_at: :desc)
  end

  def show
  end

  def new
    @doctor = current_clinic.doctors.new
  end

  def create
    @doctor = current_clinic.doctors.new(doctor_params)
    if @doctor.save
      redirect_to doctors_path, notice: t("flash.doctors.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @doctor.update(doctor_params)
      redirect_to doctors_path, notice: t("flash.doctors.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @doctor.destroy
    redirect_to doctors_path, notice: t("flash.doctors.deleted")
  end

  private

  def set_doctor
    @doctor = current_clinic.doctors.find(params[:id])
  end

  def doctor_params
    params.require(:doctor).permit(:name, :specialty, :phone, :work_start, :work_end)
  end
end
