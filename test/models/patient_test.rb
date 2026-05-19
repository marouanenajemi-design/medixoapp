require "test_helper"

class PatientTest < ActiveSupport::TestCase
  test "requires a name and phone number" do
    patient = Patient.new(clinic: clinics(:one), name: "", phone: "")

    assert_not patient.valid?
    assert_includes patient.errors[:name], "can't be blank"
    assert_includes patient.errors[:phone], "can't be blank"
  end

  test "rejects impossible ages" do
    patient = Patient.new(clinic: clinics(:one), name: "Invalid Age", phone: "555-1111", age: 0)

    assert_not patient.valid?
    assert_includes patient.errors[:age], "must be greater than 0"

    patient.age = 200
    assert_not patient.valid?
    assert_includes patient.errors[:age], "must be less than or equal to 130"
  end
end
