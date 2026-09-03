module ApplicationHelper
  # Safe active-nav helper — compares request.path to avoid locale-query-param
  # issues that cause stringify_keys errors with current_page?
  def active_path(path)
    request.path == path.to_s.split("?").first ? "active" : ""
  rescue StandardError
    ""
  end

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

  def smtp_configured?
    ENV["SMTP_USER_NAME"].present? && ENV["SMTP_PASSWORD"].present?
  end

  # ── Billing ──────────────────────────────────────────────────────────────────

  # Formats an amount stored in cents: money(250) => "€2.50"
  def money(cents, currency = nil)
    number_to_currency(
      cents.to_i / 100.0,
      unit: BillingSetting.symbol_for(currency || default_billing_currency),
      precision: 2
    )
  end

  # Memoised per request — the billing settings row is a single global record.
  def default_billing_currency
    @_default_billing_currency ||= BillingSetting.current.currency
  end

  def billing_currency_symbol(currency = nil)
    BillingSetting.symbol_for(currency || default_billing_currency)
  end

  # Value for a point-of-sale amount input: the amount already charged for this
  # visit, otherwise the clinic's suggested price as a starting point.
  def visit_amount_field_value(appointment, clinic)
    cents = appointment.visit&.price_cents || clinic.effective_price_per_visit_cents
    format("%.2f", cents.to_i / 100.0)
  end

  # ── LemonSqueezy ─────────────────────────────────────────────────────────────

  LS_CHECKOUT_URLS = {
    "starter"    => "https://medixoapp-saas.lemonsqueezy.com/checkout/buy/9267c813-60db-47ed-93dd-1cfd305f3435?enabled=1724184",
    "pro"        => "https://medixoapp-saas.lemonsqueezy.com/checkout/buy/81feecd5-10a4-496d-adfc-b0d4b85861c3?enabled=1724194",
    "clinic_plus" => "https://medixoapp-saas.lemonsqueezy.com/checkout/buy/6167c57f-2675-467b-a721-b89226b48a27?enabled=1724195"
  }.freeze

  # Builds a LemonSqueezy checkout URL pre-filled with user email and clinic_id.
  # clinic_id is passed as custom_data so the webhook can identify the clinic
  # without relying on email matching alone.
  def lemon_checkout_url(plan_tier, user: nil, clinic: nil)
    base = LS_CHECKOUT_URLS[plan_tier.to_s]
    return "#" if base.blank?

    parts = []
    parts << "checkout[email]=#{CGI.escape(user.email)}"  if user&.email.present?
    parts << "checkout[custom][clinic_id]=#{clinic.id}"   if clinic&.id.present?

    return base if parts.empty?

    # base already has a `?` from the `?enabled=` param — append with `&`
    "#{base}&#{parts.join('&')}"
  end
end
