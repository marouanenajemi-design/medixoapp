# Super Admin monetization dashboard — usage-based revenue calculated from the
# real visit ledger, plus the global "price per visit" setting.
class Admin::MonetizationController < Admin::BaseController
  MONTHS_OF_HISTORY = 6

  def show
    @setting = BillingSetting.current
    @period  = Date.current.beginning_of_month..Date.current.end_of_month

    period_visits = Visit.billable.in_period(@period)

    @total_visits  = Visit.billable.count
    @period_visits = period_visits.count
    @voided_visits = Visit.voided.count

    @total_revenue_cents  = Visit.usage_revenue_cents
    @period_revenue_cents = Visit.usage_revenue_cents(period_visits)

    @average_visit_cents = @total_visits.zero? ? 0 : (@total_revenue_cents.to_f / @total_visits).round

    @clinic_rows           = clinic_rows(@period)
    @doctor_rows           = doctor_rows
    @billing_clinics_count = @clinic_rows.count { |row| row[:period_visits].positive? }
    @usage_by_month        = usage_by_month
  end

  def update
    @setting = BillingSetting.current

    if @setting.update(setting_params)
      redirect_to admin_monetization_path,
                  notice: t("admin.monetization.flash.price_updated",
                            price: helpers.money(@setting.price_per_visit_cents, @setting.currency))
    else
      redirect_to admin_monetization_path, alert: t("admin.monetization.flash.price_invalid")
    end
  end

  private

  def setting_params
    params.require(:billing_setting).permit(:price_per_visit, :currency)
  end

  # One row per clinic: visits and revenue summed from the amounts actually
  # charged at each point of sale.
  def clinic_rows(period)
    period_totals = Visit.revenue_by_clinic(Visit.billable.in_period(period))
    total_totals  = Visit.revenue_by_clinic

    Clinic.includes(:user).order(created_at: :desc).map do |clinic|
      period_row = period_totals[clinic.id] || { visits: 0, revenue_cents: 0 }
      total_row  = total_totals[clinic.id]  || { visits: 0, revenue_cents: 0 }

      {
        clinic:              clinic,
        suggested_cents:     clinic.effective_price_per_visit_cents,
        custom_price:        clinic.custom_price_per_visit?,
        period_visits:       period_row[:visits],
        total_visits:        total_row[:visits],
        period_amount_cents: period_row[:revenue_cents],
        total_amount_cents:  total_row[:revenue_cents]
      }
    end
  end

  # Doctor | clinic | visits | revenue, across the whole platform.
  def doctor_rows
    rows = Visit.revenue_by_doctor
    doctors = Doctor.includes(:clinic).where(id: rows.map { |r| r[:doctor_id] }.compact).index_by(&:id)

    rows.map { |row| row.merge(doctor: doctors[row[:doctor_id]]) }
  end

  # Platform-wide visits and usage revenue per month, oldest first.
  def usage_by_month
    (MONTHS_OF_HISTORY - 1).downto(0).map do |months_ago|
      month_start = months_ago.months.ago.beginning_of_month.to_date
      scope       = Visit.billable.in_period(month_start..month_start.end_of_month)

      {
        month:   month_start.strftime("%b %Y"),
        visits:  scope.count,
        revenue: (Visit.usage_revenue_cents(scope).to_d / 100).to_f
      }
    end
  end
end
