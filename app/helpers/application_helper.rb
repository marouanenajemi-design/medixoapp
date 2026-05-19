module ApplicationHelper
  def formatted_time(value, fallback: "")
    value.present? ? value.strftime("%H:%M") : fallback
  end

  def locale_switch_link(locale)
    link_to t("locales.#{locale}"), url_for(locale: locale), class: "locale-link #{'active' if I18n.locale == locale}"
  end

  def form_errors_heading
    t("forms.errors_heading")
  end

  def appointment_status_label(status)
    t("appointments.statuses.#{status}", default: status.to_s.humanize)
  end

  def appointment_status_badge_class(status)
    case status
    when "confirmed" then "badge-confirmed"
    when "pending" then "badge-pending"
    when "completed" then "badge-completed"
    when "cancelled" then "badge-cancelled"
    else "badge-completed"
    end
  end


  def appointment_status_options
    Appointment::STATUSES.map { |status| [appointment_status_label(status), status] }
  end

  def patient_gender_label(gender)
    t("patients.genders.#{gender.to_s.downcase}", default: gender.to_s)
  end

  def patient_gender_options
    %w[Male Female].map { |gender| [patient_gender_label(gender), gender] }
  end

  def appointment_start_iso(appointment)
    return nil if appointment.appointment_date.blank?

    time_component = appointment.appointment_time&.strftime("%H:%M:%S") || "00:00:00"
    "#{appointment.appointment_date}T#{time_component}"
  end

  def clinic_brand_image(clinic)
    return "default-clinic-logo.svg" unless clinic&.logo&.attached?

    clinic.logo
  end
end
