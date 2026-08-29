require "test_helper"
require "minitest/mock"

# How a completed appointment turns into exactly one billable visit.
class AppointmentBillingTest < ActiveSupport::TestCase
  setup do
    @clinic  = clinics(:one)
    @doctor  = doctors(:one)
    @patient = patients(:one)
    BillingSetting.current.update!(price_per_visit_cents: 200, currency: "EUR")
  end

  def create_appointment(status:, time: "11:00", date: Date.current)
    Appointment.create!(
      clinic:           @clinic,
      doctor:           @doctor,
      patient:          @patient,
      appointment_date: date,
      appointment_time: time,
      status:           status
    )
  end

  test "a completed appointment records one billable visit" do
    assert_difference -> { @clinic.visits.billable.count }, 1 do
      create_appointment(status: "completed")
    end

    visit = @clinic.visits.billable.last

    assert_equal @patient.id, visit.patient_id
    assert_equal @doctor.id, visit.doctor_id
    assert_equal Date.current, visit.occurred_on
    assert_equal "appointment", visit.source
    assert_equal 200, visit.price_cents
  end

  test "pending, confirmed and cancelled appointments are not billed" do
    assert_no_difference -> { Visit.count } do
      create_appointment(status: "pending", time: "11:00")
      create_appointment(status: "confirmed", time: "12:00")
      create_appointment(status: "cancelled", time: "13:00")
    end
  end

  test "completing an existing appointment bills it" do
    appointment = create_appointment(status: "confirmed")

    assert_difference -> { @clinic.visits.billable.count }, 1 do
      appointment.update!(status: "completed")
    end
  end

  test "saving a completed appointment again does not bill it twice" do
    appointment = create_appointment(status: "completed")

    assert_no_difference -> { Visit.count } do
      appointment.update!(notes: "patient came back for the results")
      appointment.update!(status: "completed")
      appointment.touch
    end
  end

  test "cancelling a completed appointment stops it being billed but keeps the record" do
    appointment = create_appointment(status: "completed")

    assert_difference -> { @clinic.visits.billable.count }, -1 do
      assert_no_difference -> { Visit.count } do
        appointment.update!(status: "cancelled")
      end
    end

    assert_not Visit.find_by(appointment_id: appointment.id).billable?
  end

  test "re-completing an appointment restores the same visit rather than adding one" do
    appointment = create_appointment(status: "completed")
    appointment.update!(status: "cancelled")

    assert_no_difference -> { Visit.count } do
      appointment.update!(status: "completed")
    end

    assert_equal 1, @clinic.visits.billable.count
  end

  test "rescheduling a completed appointment moves the visit to the new date" do
    appointment = create_appointment(status: "completed")
    new_date = Date.current + 3.days

    appointment.update!(appointment_date: new_date)

    assert_equal new_date, Visit.find_by(appointment_id: appointment.id).occurred_on
  end

  test "deleting the appointment keeps the visit on the clinic's bill" do
    appointment = create_appointment(status: "completed")

    assert_no_difference -> { @clinic.visits.billable.count } do
      appointment.destroy!
    end

    assert_nil @clinic.visits.billable.last.appointment_id
  end

  test "each completed appointment is billed separately" do
    assert_difference -> { @clinic.visits.billable.count }, 2 do
      create_appointment(status: "completed", time: "11:00")
      create_appointment(status: "completed", time: "12:00")
    end
  end

  test "a billing failure never blocks the clinical record" do
    VisitBillingService.stub(:sync_appointment, ->(_appointment) { raise "billing is down" }) do
      appointment = create_appointment(status: "completed")

      assert appointment.persisted?
      assert_equal 0, Visit.count
    end
  end

  test "backfill rebuilds the ledger for appointments completed before billing existed" do
    appointment = create_appointment(status: "completed")
    Visit.delete_all

    result = VisitBillingService.backfill!

    assert_equal 1, result[:created]
    assert_equal 1, @clinic.visits.billable.count
    assert_equal appointment.id, @clinic.visits.billable.first.appointment_id
  end

  test "backfill is idempotent" do
    create_appointment(status: "completed")

    assert_no_difference -> { Visit.count } do
      VisitBillingService.backfill!
      VisitBillingService.backfill!
    end
  end

  test "backfill voids ledger rows whose appointment is no longer completed" do
    appointment = create_appointment(status: "completed")
    appointment.update_column(:status, "cancelled") # skips callbacks, as a stale record would

    result = VisitBillingService.backfill!

    assert_equal 1, result[:voided]
    assert_equal 0, @clinic.visits.billable.count
  end
end
