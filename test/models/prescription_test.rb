require "test_helper"

class PrescriptionTest < ActiveSupport::TestCase
  setup do
    @clinic = clinics(:one)
    @doctor = doctors(:one)
    @patient = patients(:one)
  end

  test "requires a prescription date" do
    prescription = Prescription.new(clinic: @clinic, doctor: @doctor, patient: @patient, prescription_date: nil)

    assert_not prescription.valid?
    assert_includes prescription.errors[:prescription_date], "can't be blank"
  end

  test "requires doctor and patient to belong to the prescription clinic" do
    prescription = Prescription.new(
      clinic: @clinic,
      doctor: doctors(:two),
      patient: patients(:two),
      prescription_date: Date.new(2026, 3, 12)
    )

    assert_not prescription.valid?
    assert_includes prescription.errors[:doctor], "must belong to your clinic"
    assert_includes prescription.errors[:patient], "must belong to your clinic"
  end

  test "rejects blank nested prescription items" do
    prescription = Prescription.create!(
      clinic: @clinic,
      doctor: @doctor,
      patient: @patient,
      prescription_date: Date.new(2026, 3, 12),
      prescription_items_attributes: {
        "0" => {
          medicine_name: "Amoxicillin",
          dosage: "500mg",
          frequency: "Twice daily",
          duration: "5 days",
          instructions: "After meals"
        },
        "1" => {
          medicine_name: "",
          dosage: "",
          frequency: "",
          duration: "",
          instructions: ""
        }
      }
    )

    assert_equal ["Amoxicillin"], prescription.prescription_items.pluck(:medicine_name)
  end

  test "blanking an existing medicine row marks it for removal" do
    prescription = prescriptions(:one)
    item = prescription.prescription_items.first

    updated = prescription.update(
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
    )

    assert updated
    assert_empty prescription.reload.prescription_items
  end
end
