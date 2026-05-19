class ApplicationController < ActionController::Base
  before_action :set_locale
  before_action :authenticate_user!
  before_action :check_clinic_access


  helper_method :current_clinic

  private

  def set_locale
    requested_locale = params[:locale].presence || session[:locale].presence || I18n.default_locale
    locale = requested_locale.to_sym
    locale = I18n.default_locale unless I18n.available_locales.include?(locale)

    I18n.locale = locale
    session[:locale] = locale
  end

  def default_url_options
    { locale: I18n.locale }
  end

  def current_clinic
    current_user&.clinic
  end

  def ensure_clinic!
    return if current_clinic.present?
    return redirect_to admin_root_path if current_user&.super_admin?

    redirect_to new_clinic_path, alert: t("flash.clinics.setup_required")
  end

  def check_clinic_access
    return unless user_signed_in?
    return unless current_user.respond_to?(:clinic)

    allowed_controllers = [
      "devise/sessions",
      "devise/registrations",
      "devise/passwords",
      "clinics",
      "pages",
      "webhooks"
    ]

    return if allowed_controllers.include?(controller_path)

    if current_clinic.blank?
      return redirect_to admin_root_path if current_user.super_admin?

      redirect_to new_clinic_path, alert: t("flash.clinics.setup_required")
      return
    end

    return if current_clinic.access_active?

    redirect_to pricing_path, alert: "Your free trial has ended. Please subscribe to continue using MedixoApp."
  end
end
