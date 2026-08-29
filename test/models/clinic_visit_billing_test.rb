require "test_helper"

# Clinic-level billing maths: price resolution, usage counts and amount due.
class ClinicVisitBillingTest < ActiveSupport::TestCase
  setup do
    @clinic = clinics(:one)
    @other  = clinics(:two)
    BillingSetting.current.update!(price_per_visit_cents: 200, currency: "EUR")
  end

  def record_visit(clinic: @clinic, occurred_on: Date.current, voided: false)
    visit = Visit.create!(
      clinic:      clinic,
      occurred_on: occurred_on,
      source:      "appointment",
      price_cents: clinic.effective_price_per_visit_cents,
      currency:    "EUR"
    )
    visit.void! if voided
    visit
  end

  test "uses the global price when the clinic has no override" do
    assert_not @clinic.custom_price_per_visit?
    assert_equal 200, @clinic.effective_price_per_visit_cents
    assert_equal BigDecimal("2"), @clinic.effective_price_per_visit
  end

  test "a clinic override wins over the global price" do
    @clinic.update!(price_per_visit_cents: 750)

    assert @clinic.custom_price_per_visit?
    assert_equal 750, @clinic.effective_price_per_visit_cents
    assert_equal 200, @other.effective_price_per_visit_cents
  end

  test "changing the global price moves every clinic without an override" do
    BillingSetting.current.update!(price_per_visit_cents: 350)

    assert_equal 350, @clinic.effective_price_per_visit_cents
  end

  test "a negative override is rejected" do
    @clinic.price_per_visit_cents = -100

    assert_not @clinic.valid?
  end

  test "counts only this clinic's billable visits" do
    2.times { record_visit }
    record_visit(clinic: @other)
    record_visit(voided: true)

    assert_equal 2, @clinic.total_billable_visits_count
    assert_equal 1, @other.total_billable_visits_count
  end

  test "the current period covers the calendar month" do
    record_visit(occurred_on: Date.current)
    record_visit(occurred_on: Date.current.beginning_of_month)
    record_visit(occurred_on: 1.month.ago.beginning_of_month.to_date)

    assert_equal 2, @clinic.current_period_visits_count
    assert_equal 3, @clinic.total_billable_visits_count
  end

  test "amount due is visits multiplied by the price per visit" do
    3.times { record_visit }

    assert_equal 600, @clinic.current_period_amount_due_cents
    assert_equal 600, @clinic.total_amount_due_cents
  end

  test "amount due follows the clinic's own price" do
    3.times { record_visit }
    @clinic.update!(price_per_visit_cents: 500)

    assert_equal 1500, @clinic.reload.current_period_amount_due_cents
  end

  test "voided visits are not charged" do
    record_visit
    record_visit(voided: true)

    assert_equal 1, @clinic.current_period_visits_count
    assert_equal 200, @clinic.current_period_amount_due_cents
  end

  test "billing summary carries everything the screens need" do
    2.times { record_visit }
    record_visit(occurred_on: 1.month.ago.beginning_of_month.to_date)

    summary = @clinic.billing_summary

    assert_equal "EUR", summary[:currency]
    assert_equal 200, summary[:price_per_visit_cents]
    assert_equal false, summary[:custom_price]
    assert_equal 2, summary[:period_visits]
    assert_equal 3, summary[:total_visits]
    assert_equal 400, summary[:period_amount_cents]
    assert_equal 600, summary[:total_amount_cents]
    assert_equal Date.current.beginning_of_month, summary[:period].first
  end

  test "a clinic with no visits owes nothing" do
    summary = @clinic.billing_summary

    assert_equal 0, summary[:total_visits]
    assert_equal 0, summary[:total_amount_cents]
  end

  test "monthly history covers the requested number of months" do
    record_visit
    record_visit(occurred_on: 1.month.ago.beginning_of_month.to_date)

    history = @clinic.visit_counts_by_month(months: 3)

    assert_equal 3, history.length
    assert_equal 1, history.last[:count]
    assert_equal 200, history.last[:amount_cents]
    assert_equal Date.current.strftime("%b %Y"), history.last[:month]
  end

  test "destroying a clinic removes its ledger and leaves other clinics alone" do
    record_visit
    record_visit(clinic: @other)

    assert_difference -> { Visit.count }, -1 do
      @clinic.destroy!
    end

    assert_equal 1, @other.total_billable_visits_count
  end
end
