require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest

  setup do
    @owner = users(:one)
    @clinicless_user = users(:three)
  end

  test "authenticated owners with a clinic can view the dashboard" do
    sign_in_as(@owner)

    get dashboard_url


  test "should get index" do
    sign_in users(:one)

    get dashboard_url

    assert_response :success
    assert_includes response.body, I18n.t("dashboard.index.recent_appointments")
    assert_includes response.body, I18n.t("dashboard.index.upcoming_appointments")
    assert_includes response.body, I18n.t("dashboard.index.status_breakdown.title")
  end

  test "authenticated users without a clinic are redirected to setup" do
    sign_in_as(@clinicless_user)

    get dashboard_url

    assert_redirected_to new_clinic_path(locale: current_locale)
  end
end
