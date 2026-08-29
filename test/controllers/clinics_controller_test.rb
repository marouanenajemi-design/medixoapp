require "test_helper"

class ClinicsControllerTest < ActionDispatch::IntegrationTest

  setup do
    @owner = users(:one)
    @clinic = clinics(:one)
    @clinicless_user = users(:three)
  end

  test "clinicless users can access setup and create their clinic" do
    sign_in_as(@clinicless_user)


  test "should get new when user has no clinic" do
    sign_in users(:one)
    users(:one).clinic.destroy!


    get new_clinic_url
    assert_response :success

    assert_difference("Clinic.count", 1) do
      post clinic_url, params: {
        clinic: {
          name: "Northside Health",
          address: "12 Main Street",
          phone: "555-8888"
        }
      }
    end

    created_clinic = @clinicless_user.reload.clinic
    assert_redirected_to dashboard_path(locale: current_locale)
    assert_equal "Northside Health", created_clinic.name
    assert_equal @clinicless_user, created_clinic.user
  end


  test "users with a clinic are redirected from setup to edit" do
    sign_in_as(@owner)

    get new_clinic_url

    assert_redirected_to edit_clinic_path(locale: current_locale)
  end

  test "owners can update their clinic details" do
    sign_in_as(@owner)

    patch clinic_url, params: {
      clinic: {
        name: "MedixoApp Central",
        address: "99 Updated Ave",
        phone: "555-0101"
      }
    }

    assert_redirected_to dashboard_path(locale: current_locale)
    @clinic.reload
    assert_equal "MedixoApp Central", @clinic.name
    assert_equal "99 Updated Ave", @clinic.address
    assert_equal "555-0101", @clinic.phone

  test "should get edit" do
    sign_in users(:one)

    get edit_clinic_url
    assert_response :success

  end
end
