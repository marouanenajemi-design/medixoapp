# Usage-based billing for a clinic: how many patient visits it recorded, what it
# pays per visit, and what it owes.
#
#   amount due = billable visits × price per visit
#
# The price per visit is the clinic's own override when set, otherwise the
# global BillingSetting value. The billing period is the current calendar month.
module VisitBilling
  extend ActiveSupport::Concern

  # ── Price ───────────────────────────────────────────────────────────────────

  def custom_price_per_visit?
    price_per_visit_cents.present?
  end

  def effective_price_per_visit_cents
    price_per_visit_cents || BillingSetting.current.price_per_visit_cents
  end

  def effective_price_per_visit
    effective_price_per_visit_cents.to_d / 100
  end

  def billing_currency
    BillingSetting.current.currency
  end

  # ── Usage ───────────────────────────────────────────────────────────────────

  def billable_visits
    visits.billable
  end

  def total_billable_visits_count
    billable_visits.count
  end

  def current_billing_period
    Date.current.beginning_of_month..Date.current.end_of_month
  end

  def billable_visits_count_in(period)
    billable_visits.in_period(period).count
  end

  def current_period_visits_count
    billable_visits_count_in(current_billing_period)
  end

  # ── Amount due ──────────────────────────────────────────────────────────────

  def total_amount_due_cents
    total_billable_visits_count * effective_price_per_visit_cents
  end

  def current_period_amount_due_cents
    current_period_visits_count * effective_price_per_visit_cents
  end

  # Everything the billing screens need, in one call.
  def billing_summary
    price_cents   = effective_price_per_visit_cents
    total_visits  = total_billable_visits_count
    period_visits = current_period_visits_count

    {
      currency:              billing_currency,
      price_per_visit_cents: price_cents,
      custom_price:          custom_price_per_visit?,
      period:                current_billing_period,
      total_visits:          total_visits,
      period_visits:         period_visits,
      total_amount_cents:    total_visits * price_cents,
      period_amount_cents:   period_visits * price_cents
    }
  end

  # Billable visits per month for the last `months` months, oldest first.
  def visit_counts_by_month(months: 6)
    (months - 1).downto(0).map do |months_ago|
      month_start = months_ago.months.ago.beginning_of_month.to_date
      count = billable_visits_count_in(month_start..month_start.end_of_month)

      {
        month:        month_start.strftime("%b %Y"),
        count:        count,
        amount_cents: count * effective_price_per_visit_cents
      }
    end
  end
end
