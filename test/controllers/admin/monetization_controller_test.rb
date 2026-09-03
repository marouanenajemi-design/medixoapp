require "test_helper"

class Admin::MonetizationControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(email: "monetization-admin@example.com",
                          password: "password123", super_admin: true)
    @clinic = clinics(:one)
    @other  = clinics(:two)
    BillingSetting.current.update!(price_per_visit_cents: 200, currency: "EUR")
  end

  def record_visit(clinic:, occurred_on: Date.current)
    Visit.create!(clinic: clinic, occurred_on: occurred_on, source: "appointment",
                  price_cents: clinic.effective_price_per_visit_cents, currency: "EUR")
  end

  test "requires a signed-in super admin" do
    get admin_monetization_url

    assert_redirected_to admin_sign_in_path(locale: current_locale)
  end

  test "rejects a regular clinic owner" do
    sign_in_as(users(:one))

    get admin_monetization_url

    assert_redirected_to admin_sign_in_path(locale: current_locale)
  end

  test "shows revenue calculated from real visits" do
    2.times { record_visit(clinic: @clinic) }
    3.times { record_visit(clinic: @other) }
    sign_in_as(@admin)

    get admin_monetization_url

    assert_response :success
    # 5 billable visits × €2.00
    assert_match "€10.00", response.body
    assert_match I18n.t("admin.monetization.title"), response.body
  end

  test "does not count voided visits in revenue" do
    record_visit(clinic: @clinic)
    record_visit(clinic: @clinic).void!
    sign_in_as(@admin)

    get admin_monetization_url

    assert_response :success
    assert_match "€2.00", response.body
  end

  test "the super admin can change the global price per visit" do
    sign_in_as(@admin)

    patch admin_monetization_url, params: { billing_setting: { price_per_visit: "3.50", currency: "EUR" } }

    assert_redirected_to admin_monetization_path(locale: current_locale)
    assert_equal 350, BillingSetting.current.price_per_visit_cents
  end

  test "a new suggested amount never changes revenue already recorded" do
    2.times { record_visit(clinic: @clinic) }
    sign_in_as(@admin)

    patch admin_monetization_url, params: { billing_setting: { price_per_visit: "10", currency: "EUR" } }

    # The two visits were charged 200 each at their own point of sale; changing
    # the suggested amount afterwards must leave that history alone.
    assert_equal 400, @clinic.reload.total_amount_due_cents
    assert_equal 400, Visit.usage_revenue_cents
    assert_equal 1000, BillingSetting.current.price_per_visit_cents
  end

  test "the doctor breakdown aggregates revenue per doctor" do
    doctor = doctors(:one)
    Visit.create!(clinic: @clinic, doctor: doctor, occurred_on: Date.current,
                  source: "appointment", price_cents: 2000, currency: "EUR")
    Visit.create!(clinic: @clinic, doctor: doctor, occurred_on: Date.current,
                  source: "appointment", price_cents: 3500, currency: "EUR")
    sign_in_as(@admin)

    get admin_monetization_url

    assert_response :success
    assert_select "th", text: I18n.t("admin.monetization.doctors.doctor")
    assert_match doctor.name, response.body
    assert_match "€55.00", response.body
  end

  test "an invalid price is rejected and the old price kept" do
    sign_in_as(@admin)

    patch admin_monetization_url, params: { billing_setting: { price_per_visit: "free", currency: "EUR" } }

    assert_redirected_to admin_monetization_path(locale: current_locale)
    assert_equal 200, BillingSetting.current.price_per_visit_cents
  end

  test "the currency can be changed" do
    sign_in_as(@admin)

    patch admin_monetization_url, params: { billing_setting: { price_per_visit: "2.00", currency: "USD" } }

    assert_equal "USD", BillingSetting.current.currency
  end

  test "the platform dashboard reports usage revenue from real visits" do
    2.times { record_visit(clinic: @clinic) }
    sign_in_as(@admin)

    get admin_root_url

    assert_response :success
    assert_match I18n.t("admin.dashboard.usage.title"), response.body
    assert_match "€4.00", response.body
  end

  test "a regular user cannot change the price" do
    sign_in_as(users(:one))

    patch admin_monetization_url, params: { billing_setting: { price_per_visit: "99", currency: "EUR" } }

    assert_redirected_to admin_sign_in_path(locale: current_locale)
    assert_equal 200, BillingSetting.current.price_per_visit_cents
  end
end
