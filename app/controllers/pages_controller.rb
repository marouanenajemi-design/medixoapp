class PagesController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :check_clinic_access

  layout "landing", only: [:home]

  def home
    redirect_to dashboard_path if user_signed_in?
  end

  def pricing
  end
end
