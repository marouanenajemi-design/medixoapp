require "test_helper"

class DoctorTest < ActiveSupport::TestCase
  test "requires work start and end times" do
    doctor = Doctor.new(
      clinic: clinics(:one),
      name: "Dr. Missing Hours",
      specialty: "General",
      phone: "555-1212",
      work_start: nil,
      work_end: nil
    )

    assert_not doctor.valid?
    assert_includes doctor.errors[:work_start], "can't be blank"
    assert_includes doctor.errors[:work_end], "can't be blank"
  end

  test "requires the work end time to be after the start time" do
    doctor = Doctor.new(
      clinic: clinics(:one),
      name: "Dr. Wrong Hours",
      specialty: "General",
      phone: "555-1212",
      work_start: "17:00",
      work_end: "09:00"
    )

    assert_not doctor.valid?
    assert_includes doctor.errors[:work_end], "must be after the start time"
  end
end
