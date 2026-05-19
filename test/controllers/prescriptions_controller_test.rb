require "test_helper"

class PrescriptionsControllerTest < ActionDispatch::IntegrationTest

  setup do
    @owner = users(:one)
    @clinic = clinics(:one)
    @prescription = prescriptions(:one)
    @doctor = doctors(:one)
    @patient = patients(:one)
    @other_doctor = doctors(:two)
  end

  test "authenticated clinic owners can browse prescription pages" do
    sign_in_as(@owner)

    get prescriptions_url
    assert_response :success

    get prescription_url(@prescription)

  test "should get index" do
    sign_in users(:one)

    get prescriptions_url
    assert_response :success
  end

  test "should get show" do
    sign_in users(:one)

    get prescription_url(prescriptions(:one))

    assert_response :success


    get new_prescription_url
    assert_response :success

    get edit_prescription_url(@prescription)

  test "should get new" do
    sign_in users(:one)

    get new_prescription_url

    assert_response :success


    get print_prescription_url(@prescription)
    assert_response :success
  end

  test "owners can create prescriptions with nested medicine items" do
    sign_in_as(@owner)

    assert_difference(["Prescription.count", "PrescriptionItem.count"], 1) do
      post prescriptions_url, params: {
        prescription: {
          prescription_date: Date.new(2026, 3, 11),
          diagnosis: "Seasonal allergies",
          notes: "Take with water",
          doctor_id: @doctor.id,
          patient_id: @patient.id,
          prescription_items_attributes: {
            "0" => {
              medicine_name: "Cetirizine",
              dosage: "10mg",
              frequency: "Once daily",
              duration: "7 days",
              instructions: "Take after dinner"
            },
            "1" => {
              medicine_name: "",
              dosage: "",
              frequency: "",
              duration: "",
              instructions: ""
            }
          }
        }
      }
    end

    prescription = Prescription.order(:id).last
    assert_redirected_to prescription_path(prescription, locale: current_locale)
    assert_equal @clinic, prescription.clinic
    assert_equal ["Cetirizine"], prescription.prescription_items.pluck(:medicine_name)

  test "should get print" do
    sign_in users(:one)

    get print_prescription_url(prescriptions(:one))
    assert_response :success

  end

  test "prescription creation fails when related records are outside the clinic" do
    sign_in_as(@owner)

    assert_no_difference("Prescription.count") do
      post prescriptions_url, params: {
        prescription: {
          prescription_date: Date.new(2026, 3, 11),
          diagnosis: "Cross-clinic doctor",
          notes: "Should fail",
          doctor_id: @other_doctor.id,
          patient_id: @patient.id,
          prescription_items_attributes: {
            "0" => {
              medicine_name: "Cetirizine",
              dosage: "10mg",
              frequency: "Once daily",
              duration: "7 days",
              instructions: "Take after dinner"
            }
          }
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "owners can clear an existing blanked medicine row without validation failure" do
    sign_in_as(@owner)

    item = @prescription.prescription_items.first

    patch prescription_url(@prescription), params: {
      prescription: {
        prescription_date: @prescription.prescription_date,
        diagnosis: @prescription.diagnosis,
        notes: @prescription.notes,
        doctor_id: @prescription.doctor_id,
        patient_id: @prescription.patient_id,
        prescription_items_attributes: {
          "0" => {
            id: item.id,
            medicine_name: "",
            dosage: "",
            frequency: "",
            duration: "",
            instructions: ""
          }
        }
      }
    }

    assert_redirected_to prescription_path(@prescription, locale: current_locale)
    assert_empty @prescription.reload.prescription_items
  end

end
