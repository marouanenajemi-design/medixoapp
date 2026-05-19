class Admin::SessionsController < ApplicationController
  layout "admin_login"

  skip_before_action :authenticate_user!
  skip_before_action :check_clinic_access

  before_action :redirect_if_admin_signed_in, only: [:new, :create]

  def new
  end

  def create
    user = User.find_by(email: params[:email].to_s.strip.downcase)

    if user&.valid_password?(params[:password]) && user.super_admin?
      sign_in(:user, user)
      redirect_to admin_root_path, notice: t("admin.sessions.signed_in")
    elsif user&.valid_password?(params[:password])
      redirect_to admin_sign_in_path, alert: t("admin.sessions.not_super_admin")
    else
      flash.now[:alert] = t("admin.sessions.invalid_credentials")
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    sign_out(:user)
    redirect_to admin_sign_in_path, notice: t("admin.sessions.signed_out")
  end

  private

  def redirect_if_admin_signed_in
    redirect_to admin_root_path if current_user&.super_admin?
  end
end
