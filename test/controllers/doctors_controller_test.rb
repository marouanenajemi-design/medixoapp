require "test_helper"

class DoctorsControllerTest < ActionDispatch::IntegrationTest

  setup do
    @owner = users(:one)
    @clinic = clinics(:one)
    @doctor = doctors(:one)
  end

  test "authenticated clinic owners can browse doctor pages" do
    sign_in_as(@owner)

    get doctors_url
    assert_response :success

    get new_doctor_url

  test "should get index" do
    sign_in users(:one)

    get doctors_url

    assert_response :success


    get doctor_url(@doctor)
    assert_response :success

    get edit_doctor_url(@doctor)
    assert_response :success
  end

  test "owners can create doctors for their clinic" do
    sign_in_as(@owner)

    assert_difference("Doctor.count", 1) do
      post doctors_url, params: {
        doctor: {
          name: "Dr. Carter",
          specialty: "Pediatrics",
          phone: "555-4444",
          work_start: "08:30",
          work_end: "16:30"
        }
      }
    end

    doctor = Doctor.order(:id).last
    assert_redirected_to doctors_path(locale: current_locale)
    assert_equal @clinic, doctor.clinic
    assert_equal "Dr. Carter", doctor.name
  end

  test "invalid doctor submissions re-render the form" do
    sign_in_as(@owner)

    assert_no_difference("Doctor.count") do
      post doctors_url, params: {
        doctor: {
          name: "",
          specialty: "Pediatrics",
          phone: "555-4444",
          work_start: "08:30",
          work_end: "16:30"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "owners can update doctors in their clinic" do
    sign_in_as(@owner)

    patch doctor_url(@doctor), params: {
      doctor: {
        specialty: "Family Medicine",
        phone: "555-9191"
      }
    }

    assert_redirected_to doctors_path(locale: current_locale)
    @doctor.reload
    assert_equal "Family Medicine", @doctor.specialty
    assert_equal "555-9191", @doctor.phone
  end

  test "owners can delete doctors in their clinic" do
    sign_in_as(@owner)

    assert_difference("Doctor.count", -1) do
      delete doctor_url(@doctor)
    end

    assert_redirected_to doctors_path(locale: current_locale)

  test "should get show" do
    sign_in users(:one)

    get doctor_url(doctors(:one))
    assert_response :success
  end

  test "should get new" do
    sign_in users(:one)

    get new_doctor_url
    assert_response :success

  end
end
