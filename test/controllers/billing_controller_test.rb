require "test_helper"

class BillingControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner  = users(:one)
    @clinic = clinics(:one)
    @other_clinic = clinics(:two)
    BillingSetting.current.update!(price_per_visit_cents: 200, currency: "EUR")
  end

  def record_visit(clinic:, occurred_on: Date.current)
    Visit.create!(clinic: clinic, occurred_on: occurred_on, source: "appointment",
                  price_cents: clinic.effective_price_per_visit_cents, currency: "EUR")
  end

  test "requires authentication" do
    get billing_url

    assert_redirected_to new_user_session_path
  end

  test "a user without a clinic is sent to clinic setup" do
    sign_in_as(users(:three))

    get billing_url

    assert_redirected_to new_clinic_path(locale: current_locale)
  end

  test "shows visits used, price per visit and amount due" do
    2.times { record_visit(clinic: @clinic) }
    sign_in_as(@owner)

    get billing_url

    assert_response :success
    assert_select ".stat-value", text: "2"
    assert_match "€2.00", response.body
    assert_match "€4.00", response.body
  end

  test "shows a clinic with no visits an empty bill" do
    sign_in_as(@owner)

    get billing_url

    assert_response :success
    assert_match "€0.00", response.body
    assert_match I18n.t("billing.show.no_visits"), response.body
  end

  test "shows the clinic's suggested amount alongside the real average" do
    @clinic.update!(price_per_visit_cents: 500)
    record_visit(clinic: @clinic)
    sign_in_as(@owner)

    get billing_url

    assert_response :success
    assert_match "€5.00", response.body
    assert_match I18n.t("billing.show.suggested_price", amount: "€5.00"), response.body
  end

  test "totals are the sum of each visit's own amount, not a count times a price" do
    Visit.create!(clinic: @clinic, occurred_on: Date.current, source: "appointment",
                  price_cents: 2000, currency: "EUR")
    Visit.create!(clinic: @clinic, occurred_on: Date.current, source: "appointment",
                  price_cents: 3500, currency: "EUR")
    Visit.create!(clinic: @clinic, occurred_on: Date.current, source: "appointment",
                  price_cents: 1500, currency: "EUR")
    sign_in_as(@owner)

    get billing_url

    assert_response :success
    assert_match "€70.00", response.body
    assert_select ".stat-value", text: "3"
    assert_no_match(/visits × /, response.body)
  end

  test "the billing page breaks revenue down by doctor" do
    doctor = doctors(:one)
    Visit.create!(clinic: @clinic, doctor: doctor, occurred_on: Date.current,
                  source: "appointment", price_cents: 2000, currency: "EUR")
    Visit.create!(clinic: @clinic, doctor: doctor, occurred_on: Date.current,
                  source: "appointment", price_cents: 3500, currency: "EUR")
    sign_in_as(@owner)

    get billing_url

    assert_response :success
    assert_match I18n.t("billing.show.by_doctor.title"), response.body
    assert_match doctor.name, response.body
    assert_match "€55.00", response.body
  end

  test "never counts another clinic's visits" do
    3.times { record_visit(clinic: @other_clinic) }
    record_visit(clinic: @clinic)
    sign_in_as(@owner)

    get billing_url

    assert_response :success
    # 1 visit × €2.00 — the other clinic's 3 visits are invisible here.
    assert_match "€2.00", response.body
    assert_no_match(/€6\.00/, response.body)
  end

  test "only lists this clinic's visits" do
    record_visit(clinic: @clinic)
    record_visit(clinic: @other_clinic)
    sign_in_as(@owner)

    get billing_url

    assert_response :success
    assert_select "tbody tr", minimum: 1
    assert_equal 1, @clinic.visits.billable.count
  end

  test "a clinic whose access lapsed can still see what it owes" do
    @clinic.update!(subscribed: false, trial_ends_at: 2.days.ago)
    record_visit(clinic: @clinic)
    sign_in_as(@owner)

    get billing_url

    assert_response :success
    assert_select "h1.page-title", text: I18n.t("billing.show.title")
    assert_match "€2.00", response.body
  end

  test "the clinic dashboard shows the visit billing card" do
    @clinic.update!(trial_ends_at: 10.days.from_now)
    2.times { record_visit(clinic: @clinic) }
    sign_in_as(@owner)

    get dashboard_url

    assert_response :success
    assert_match I18n.t("dashboard.index.billing.title"), response.body
    assert_match "€4.00", response.body
  end

  test "completed appointments show up on the bill" do
    sign_in_as(@owner)

    Appointment.create!(clinic: @clinic, doctor: doctors(:one), patient: patients(:one),
                        appointment_date: Date.current, appointment_time: "11:00",
                        status: "completed")

    get billing_url

    assert_response :success
    assert_match "€2.00", response.body
    assert_equal 1, @clinic.visits.billable.count
  end
end
