require "test_helper"

class AppointmentsControllerTest < ActionDispatch::IntegrationTest

  setup do
    @owner = users(:one)
    @clinic = clinics(:one)
    @appointment = appointments(:one)
    @doctor = doctors(:one)
    @patient = patients(:one)
  end

  test "authenticated clinic owners can browse appointment pages" do
    sign_in_as(@owner)

    get appointments_url
    assert_response :success

    get appointment_url(@appointment)

  test "should get index" do
    sign_in users(:one)

    get appointments_url
    assert_response :success
  end

  test "should get show" do
    sign_in users(:one)

    get appointment_url(appointments(:one))

    assert_response :success


    get new_appointment_url
    assert_response :success

    get edit_appointment_url(@appointment)

  test "should get new" do
    sign_in users(:one)

    get new_appointment_url

    assert_response :success


    get calendar_url
    assert_response :success
  end

  test "owners can create appointments for their clinic" do
    sign_in_as(@owner)

    assert_difference("Appointment.count", 1) do
      post appointments_url, params: {
        appointment: {
          appointment_date: Date.new(2026, 3, 10),
          appointment_time: "11:00",
          status: "confirmed",
          notes: "Annual checkup",
          doctor_id: @doctor.id,
          patient_id: @patient.id
        }
      }
    end

    appointment = Appointment.order(:id).last
    assert_redirected_to calendar_path(locale: current_locale)
    assert_equal @clinic, appointment.clinic
    assert_equal "confirmed", appointment.status
  end

  test "double-booked appointments are rejected" do
    sign_in_as(@owner)

    assert_no_difference("Appointment.count") do
      post appointments_url, params: {
        appointment: {
          appointment_date: @appointment.appointment_date,
          appointment_time: @appointment.appointment_time.strftime("%H:%M"),
          status: "pending",
          notes: "Conflicting slot",
          doctor_id: @appointment.doctor_id,
          patient_id: @patient.id
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "owners can update appointments in their clinic" do
    sign_in_as(@owner)

    patch appointment_url(@appointment), params: {
      appointment: {
        appointment_time: "11:30",
        status: "completed",
        notes: "Seen and discharged"
      }
    }

    assert_redirected_to calendar_path(locale: current_locale)
    @appointment.reload
    assert_equal "completed", @appointment.status
    assert_equal "11:30", @appointment.appointment_time.strftime("%H:%M")
  end

  test "owners can delete appointments in their clinic" do
    sign_in_as(@owner)

    assert_difference("Appointment.count", -1) do
      delete appointment_url(@appointment)
    end

    assert_redirected_to appointments_path(locale: current_locale)

  test "should get calendar" do
    sign_in users(:one)

    get calendar_url
    assert_response :success

  end
end
