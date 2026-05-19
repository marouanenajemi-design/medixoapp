require "test_helper"

class AppointmentTest < ActiveSupport::TestCase
  setup do
    @clinic = clinics(:one)
    @doctor = doctors(:one)
    @patient = patients(:one)
    @other_doctor = doctors(:two)
    @other_patient = patients(:two)
  end

  test "requires a valid status" do
    appointment = Appointment.new(
      clinic: @clinic,
      doctor: @doctor,
      patient: @patient,
      appointment_date: Date.new(2026, 3, 12),
      appointment_time: "13:00",
      status: "rescheduled"
    )

    assert_not appointment.valid?
    assert_includes appointment.errors[:status], "is not included in the list"
  end

  test "prevents double booking the same doctor at the same time" do
    appointment = Appointment.new(
      clinic: @clinic,
      doctor: @doctor,
      patient: @patient,
      appointment_date: appointments(:one).appointment_date,
      appointment_time: appointments(:one).appointment_time,
      status: "confirmed"
    )

    assert_not appointment.valid?
    assert_includes appointment.errors[:appointment_time], I18n.t("errors.models.appointment.attributes.appointment_time.doctor_double_booked")
  end

  test "cancelled appointments do not block a new booking in the same slot" do
    existing = appointments(:one)
    existing.update!(status: "cancelled")

    appointment = Appointment.new(
      clinic: @clinic,
      doctor: @doctor,
      patient: @patient,
      appointment_date: existing.appointment_date,
      appointment_time: existing.appointment_time,
      status: "confirmed"
    )

    assert appointment.valid?
  end

  test "requires doctor and patient to belong to the appointment clinic" do
    appointment = Appointment.new(
      clinic: @clinic,
      doctor: @other_doctor,
      patient: @other_patient,
      appointment_date: Date.new(2026, 3, 12),
      appointment_time: "14:00",
      status: "confirmed"
    )

    assert_not appointment.valid?
    assert_includes appointment.errors[:doctor], "must belong to your clinic"
    assert_includes appointment.errors[:patient], "must belong to your clinic"
  end

  test "requires appointment time to be within doctor working hours" do
    appointment = Appointment.new(
      clinic: @clinic,
      doctor: @doctor,
      patient: @patient,
      appointment_date: Date.new(2026, 3, 12),
      appointment_time: "07:30",
      status: "confirmed"
    )

    assert_not appointment.valid?
    assert_includes appointment.errors[:appointment_time], I18n.t("errors.models.appointment.attributes.appointment_time.outside_doctor_working_hours")

    appointment.appointment_time = "10:30"
    assert appointment.valid?
  end
end
