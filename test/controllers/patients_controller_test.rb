require "test_helper"

class PatientsControllerTest < ActionDispatch::IntegrationTest

  setup do
    @owner = users(:one)
    @clinic = clinics(:one)
    @patient = patients(:one)
  end

  test "authenticated clinic owners can browse patient pages" do
    sign_in_as(@owner)

    get patients_url
    assert_response :success

    get patient_url(@patient)

  test "should get index" do
    sign_in users(:one)

    get patients_url

    assert_response :success


    get history_patient_url(@patient)
    assert_response :success

    get new_patient_url

  test "should get show" do
    sign_in users(:one)

    get patient_url(patients(:one))

    assert_response :success


    get edit_patient_url(@patient)
    assert_response :success
  end

  test "owners can create patients for their clinic" do
    sign_in_as(@owner)

    assert_difference("Patient.count", 1) do
      post patients_url, params: {
        patient: {
          name: "Mary Jones",
          phone: "555-7777",
          age: 28,
          gender: "Female",
          notes: "First visit"
        }
      }
    end

    patient = Patient.order(:id).last
    assert_redirected_to patients_path(locale: current_locale)
    assert_equal @clinic, patient.clinic
    assert_equal "Mary Jones", patient.name
  end

  test "invalid patient submissions re-render the form" do
    sign_in_as(@owner)

    assert_no_difference("Patient.count") do
      post patients_url, params: {
        patient: {
          name: "",
          phone: "",
          age: 28,
          gender: "Female"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "owners can update patients in their clinic" do
    sign_in_as(@owner)

    patch patient_url(@patient), params: {
      patient: {
        phone: "555-8080",
        notes: "Updated notes"
      }
    }

    assert_redirected_to patients_path(locale: current_locale)
    @patient.reload
    assert_equal "555-8080", @patient.phone
    assert_equal "Updated notes", @patient.notes
  end

  test "owners can delete patients in their clinic" do
    sign_in_as(@owner)

    assert_difference("Patient.count", -1) do
      delete patient_url(@patient)
    end

    assert_redirected_to patients_path(locale: current_locale)

  test "should get history" do
    sign_in users(:one)

    get history_patient_url(patients(:one))
    assert_response :success

  end
end
