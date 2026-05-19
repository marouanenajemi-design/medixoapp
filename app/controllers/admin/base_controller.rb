class Admin::BaseController < ApplicationController
  layout "admin"

  skip_before_action :authenticate_user!
  skip_before_action :check_clinic_access
  before_action :require_super_admin!

  private

  def require_super_admin!
    unless user_signed_in?
      redirect_to admin_sign_in_path, alert: t("admin.sessions.sign_in_required")
      return
    end

    unless current_user.super_admin?
      redirect_to admin_sign_in_path, alert: t("admin.access_denied")
    end
  end
end
