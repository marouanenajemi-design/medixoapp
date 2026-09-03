require "test_helper"

# The point-of-sale endpoint: completing a visit and recording what was charged.
class AppointmentCompletionTest < ActionDispatch::IntegrationTest
  setup do
    @owner   = users(:one)
    @clinic  = clinics(:one)
    @clinic.update!(trial_ends_at: 10.days.from_now)
    @doctor  = doctors(:one)
    @patient = patients(:one)
    BillingSetting.current.update!(price_per_visit_cents: 200, currency: "EUR")
    sign_in_as(@owner)
  end

  def appointment(status: "confirmed", time: "11:00")
    Appointment.create!(clinic: @clinic, doctor: @doctor, patient: @patient,
                        appointment_date: Date.current, appointment_time: time, status: status)
  end

  test "completing a visit records the amount charged" do
    appt = appointment

    assert_difference -> { @clinic.visits.billable.count }, 1 do
      patch complete_appointment_url(appt), params: { visit_amount: "35.50" }
    end

    assert_redirected_to appointments_path(locale: current_locale)
    assert_equal "completed", appt.reload.status
    assert_equal 3550, appt.visit.price_cents
    assert appt.visit.amount_entered?
  end

  test "each visit can be charged a different amount" do
    a = appointment(time: "11:00")
    b = appointment(time: "12:00")
    c = appointment(time: "13:00")

    patch complete_appointment_url(a), params: { visit_amount: "20" }
    patch complete_appointment_url(b), params: { visit_amount: "35" }
    patch complete_appointment_url(c), params: { visit_amount: "15" }

    assert_equal 7000, @clinic.reload.total_amount_due_cents
    assert_equal [2000, 3500, 1500], @clinic.visits.billable.order(:id).pluck(:price_cents)
  end

  test "re-submitting the amount corrects it without creating a second visit" do
    appt = appointment
    patch complete_appointment_url(appt), params: { visit_amount: "20" }

    assert_no_difference -> { Visit.count } do
      patch complete_appointment_url(appt), params: { visit_amount: "45" }
    end

    assert_equal 4500, appt.reload.visit.price_cents
  end

  test "an invalid amount is refused with a readable message and charges nothing" do
    appt = appointment

    assert_no_difference -> { Visit.count } do
      patch complete_appointment_url(appt), params: { visit_amount: "abc" }
    end

    assert_equal "confirmed", appt.reload.status
    assert flash[:alert].present?
    assert_no_match(/translation missing/i, flash[:alert])
    assert_match(/amount/i, flash[:alert])
  end

  test "a zero amount is accepted" do
    appt = appointment
    patch complete_appointment_url(appt), params: { visit_amount: "0" }

    assert_equal 0, appt.reload.visit.price_cents
    assert appt.visit.billable?
  end

  test "another clinic's appointment cannot be completed" do
    foreign = Appointment.create!(clinic: clinics(:two), doctor: doctors(:two), patient: patients(:two),
                                  appointment_date: Date.current, appointment_time: "11:00",
                                  status: "confirmed")

    patch complete_appointment_url(foreign), params: { visit_amount: "500" }

    assert_response :not_found
    assert_equal "confirmed", foreign.reload.status
    assert_nil foreign.visit
  end

  test "the appointments list offers the point-of-sale amount field" do
    appointment

    get appointments_url

    assert_response :success
    assert_select "input[name=visit_amount]", minimum: 1
    assert_select "form[action*=complete] button", minimum: 1
    assert_select "th", text: I18n.t("appointments.index.amount")
  end

  test "the edit form carries the amount through a status change" do
    appt = appointment

    patch appointment_url(appt), params: {
      appointment: { status: "completed", visit_amount: "42.25",
                     doctor_id: @doctor.id, patient_id: @patient.id,
                     appointment_date: Date.current, appointment_time: "11:00" }
    }

    assert_equal 4225, appt.reload.visit.price_cents
  end
end
