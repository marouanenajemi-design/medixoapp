require "test_helper"

# The per-clinic price-per-visit override, set from the admin clinic page.
class Admin::ClinicVisitPriceTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(email: "pricing-admin@example.com",
                          password: "password123", super_admin: true)
    @clinic = clinics(:one)
    BillingSetting.current.update!(price_per_visit_cents: 200, currency: "EUR")
  end

  test "the clinic page shows usage and the override form" do
    Visit.create!(clinic: @clinic, occurred_on: Date.current, source: "appointment",
                  price_cents: 200, currency: "EUR")
    sign_in_as(@admin)

    get admin_clinic_url(@clinic)

    assert_response :success
    assert_match I18n.t("admin.monetization.clinic_card.title"), response.body
    assert_select "form[action=?]", update_visit_price_admin_clinic_path(@clinic, locale: current_locale)
  end

  test "the super admin can set a price for one clinic" do
    sign_in_as(@admin)

    patch update_visit_price_admin_clinic_url(@clinic), params: { price_per_visit: "7.50" }

    assert_redirected_to admin_clinic_path(@clinic, locale: current_locale)
    assert_equal 750, @clinic.reload.price_per_visit_cents
    assert_equal 750, @clinic.effective_price_per_visit_cents
  end

  test "the override only affects that clinic" do
    sign_in_as(@admin)

    patch update_visit_price_admin_clinic_url(@clinic), params: { price_per_visit: "7.50" }

    assert_equal 200, clinics(:two).reload.effective_price_per_visit_cents
  end

  test "clearing the override returns the clinic to the global price" do
    @clinic.update!(price_per_visit_cents: 750)
    sign_in_as(@admin)

    patch update_visit_price_admin_clinic_url(@clinic), params: { reset: "1" }

    assert_nil @clinic.reload.price_per_visit_cents
    assert_equal 200, @clinic.effective_price_per_visit_cents
  end

  test "an empty price also clears the override" do
    @clinic.update!(price_per_visit_cents: 750)
    sign_in_as(@admin)

    patch update_visit_price_admin_clinic_url(@clinic), params: { price_per_visit: "" }

    assert_nil @clinic.reload.price_per_visit_cents
  end

  test "an invalid price is rejected and the old one kept" do
    @clinic.update!(price_per_visit_cents: 750)
    sign_in_as(@admin)

    patch update_visit_price_admin_clinic_url(@clinic), params: { price_per_visit: "cheap" }

    assert_redirected_to admin_clinic_path(@clinic, locale: current_locale)
    assert_equal 750, @clinic.reload.price_per_visit_cents
  end

  test "a regular user cannot set a clinic's price" do
    sign_in_as(users(:one))

    patch update_visit_price_admin_clinic_url(@clinic), params: { price_per_visit: "0.01" }

    assert_redirected_to admin_sign_in_path(locale: current_locale)
    assert_nil @clinic.reload.price_per_visit_cents
  end
end
