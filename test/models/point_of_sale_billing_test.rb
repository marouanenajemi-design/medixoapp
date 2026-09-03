require "test_helper"

# The buyer's requirement: the price is decided at the point of sale and the
# admin panel aggregates the real amounts. These are the 13 scenarios that
# define that behaviour end to end.
class PointOfSaleBillingTest < ActiveSupport::TestCase
  setup do
    @clinic   = clinics(:one)
    @other    = clinics(:two)
    @doctor_a = doctors(:one)
    @doctor_b = @clinic.doctors.create!(name: "Dr. Brown", specialty: "Dermatology",
                                        phone: "555-7777", work_start: "08:00", work_end: "19:00")
    @patient  = patients(:one)
    BillingSetting.current.update!(price_per_visit_cents: 200, currency: "EUR")
  end

  def complete_visit(amount, doctor: @doctor_a, time: "11:00", date: Date.current, status: "completed")
    Appointment.create!(
      clinic: @clinic, doctor: doctor, patient: @patient,
      appointment_date: date, appointment_time: time,
      status: status, visit_amount: amount
    )
  end

  # 1
  test "a completed appointment charged 20 euro stores 2000 cents" do
    appointment = complete_visit("20")

    visit = appointment.reload.visit

    assert_equal 2000, visit.price_cents
    assert visit.billable?
    assert visit.amount_entered?, "the amount was typed at the point of sale"
  end

  # 2
  test "a second visit for the same doctor stores its own separate amount" do
    complete_visit("20", time: "11:00")
    complete_visit("35", time: "12:00")

    assert_equal [2000, 3500], @clinic.visits.billable.order(:id).pluck(:price_cents)
  end

  # 3
  test "doctor revenue is the sum of that doctor's visit amounts" do
    complete_visit("20", time: "11:00")
    complete_visit("35", time: "12:00")

    row = @clinic.revenue_by_doctor.find { |r| r[:doctor]&.id == @doctor_a.id }

    assert_equal 2, row[:visits]
    assert_equal 5500, row[:revenue_cents]
  end

  # 4
  test "a second doctor's revenue is tracked separately and the totals add up" do
    complete_visit("20", time: "11:00")
    complete_visit("35", time: "12:00")
    complete_visit("50", doctor: @doctor_b, time: "13:00")

    rows = @clinic.revenue_by_doctor.index_by { |r| r[:doctor]&.id }

    assert_equal 5500, rows[@doctor_a.id][:revenue_cents]
    assert_equal 5000, rows[@doctor_b.id][:revenue_cents]
    assert_equal 10_500, @clinic.total_amount_due_cents
    assert_equal 10_500, Visit.usage_revenue_cents
  end

  # 5
  test "a cancelled appointment adds nothing to revenue" do
    complete_visit("20", time: "11:00")

    assert_no_difference -> { Visit.usage_revenue_cents } do
      Appointment.create!(clinic: @clinic, doctor: @doctor_a, patient: @patient,
                          appointment_date: Date.current, appointment_time: "14:00",
                          status: "cancelled", visit_amount: "99")
    end

    assert_equal 2000, Visit.usage_revenue_cents
  end

  # 6
  test "a pending appointment adds nothing to revenue" do
    assert_no_difference -> { Visit.usage_revenue_cents } do
      Appointment.create!(clinic: @clinic, doctor: @doctor_a, patient: @patient,
                          appointment_date: Date.current, appointment_time: "15:00",
                          status: "pending", visit_amount: "99")
    end

    assert_equal 0, Visit.usage_revenue_cents
  end

  # 7
  test "completing the same appointment twice creates only one visit" do
    appointment = complete_visit("20")

    assert_no_difference -> { Visit.count } do
      appointment.update!(status: "completed", visit_amount: "20")
      appointment.update!(notes: "second thought")
    end

    assert_equal 1, @clinic.visits.count
    assert_equal 2000, Visit.usage_revenue_cents
  end

  # 8
  test "completed then cancelled voids the visit and removes it from revenue" do
    appointment = complete_visit("20")

    assert_no_difference -> { Visit.count } do
      appointment.update!(status: "cancelled")
    end

    assert_equal 0, Visit.usage_revenue_cents
    assert_equal 0, @clinic.reload.total_amount_due_cents
    assert_not Visit.find_by(appointment_id: appointment.id).billable?
  end

  # 9
  test "cancelled then completed again restores the same visit with its amount" do
    appointment = complete_visit("20")
    appointment.update!(status: "cancelled")

    assert_no_difference -> { Visit.count } do
      appointment.update!(status: "completed")
    end

    visit = Visit.find_by(appointment_id: appointment.id)

    assert visit.billable?
    assert_equal 2000, visit.price_cents, "the original amount survives the round trip"
    assert_equal 2000, Visit.usage_revenue_cents
  end

  # 10
  test "one clinic never sees another clinic's financial data" do
    complete_visit("20")

    other_visit = Visit.create!(clinic: @other, occurred_on: Date.current, source: "appointment",
                                price_cents: 9_999, currency: "EUR")

    assert_equal 2000, @clinic.reload.total_amount_due_cents
    assert_equal 9_999, @other.reload.total_amount_due_cents
    assert_not_includes @clinic.visits, other_visit
    assert_equal 11_999, Visit.usage_revenue_cents, "only the platform admin sees both"
  end

  # 11
  test "historical amounts are unchanged by later configuration changes" do
    complete_visit("20", time: "11:00")
    complete_visit("35", time: "12:00")
    complete_visit("15", time: "13:00")

    assert_equal 7000, @clinic.total_amount_due_cents

    BillingSetting.current.update!(price_per_visit_cents: 10_000)
    @clinic.update!(price_per_visit_cents: 25_000)

    assert_equal 7000, @clinic.reload.total_amount_due_cents
    assert_equal [2000, 3500, 1500], @clinic.visits.billable.order(:id).pluck(:price_cents)
  end

  # 12
  test "clinic totals equal the sum of the stored visit amounts" do
    complete_visit("20", time: "11:00")
    complete_visit("35", time: "12:00")

    expected = @clinic.visits.billable.sum(:price_cents)

    assert_equal expected, @clinic.total_amount_due_cents
    assert_equal expected, @clinic.current_period_amount_due_cents
    assert_equal expected, @clinic.billing_summary[:total_amount_cents]
  end

  # 13
  test "admin totals equal the sum of the stored visit amounts" do
    complete_visit("20", time: "11:00")
    complete_visit("35", time: "12:00")
    Visit.create!(clinic: @other, occurred_on: Date.current, source: "appointment",
                  price_cents: 4000, currency: "EUR")

    assert_equal Visit.billable.sum(:price_cents), Visit.usage_revenue_cents
    assert_equal 9500, Visit.usage_revenue_cents
    assert_equal 9500, Visit.revenue_by_doctor.sum { |r| r[:revenue_cents] }
    assert_equal 9500, Visit.revenue_by_clinic.values.sum { |r| r[:revenue_cents] }
  end

  # ── Validation and defaults ────────────────────────────────────────────────

  test "an amount with a decimal comma or point is accepted" do
    assert_equal 3550, complete_visit("35.50", time: "11:00").reload.visit.price_cents
    assert_equal 3550, complete_visit("35,50", time: "12:00").reload.visit.price_cents
    assert_equal 3500, complete_visit("35", time: "13:00").reload.visit.price_cents
  end

  test "a zero amount is allowed and recorded explicitly" do
    visit = complete_visit("0").reload.visit

    assert_equal 0, visit.price_cents
    assert visit.billable?
    assert visit.amount_entered?
  end

  test "a non-numeric or negative amount is rejected with a friendly message" do
    ["abc", "-5", "1.234"].each do |bad|
      appointment = Appointment.new(clinic: @clinic, doctor: @doctor_a, patient: @patient,
                                    appointment_date: Date.current, appointment_time: "16:00",
                                    status: "completed", visit_amount: bad)

      assert_not appointment.valid?, "#{bad.inspect} should be rejected"
      message = appointment.errors.full_messages_for(:visit_amount).first
      assert_match(/amount/i, message)
      assert_no_match(/translation missing/i, message)
    end
  end

  test "completing without an amount falls back to the suggested price" do
    appointment = Appointment.create!(clinic: @clinic, doctor: @doctor_a, patient: @patient,
                                      appointment_date: Date.current, appointment_time: "16:30",
                                      status: "completed")
    visit = appointment.reload.visit

    assert_equal 200, visit.price_cents
    assert_not visit.amount_entered?, "a defaulted amount is not a point-of-sale amount"
  end

  test "re-pricing a completed visit updates the amount without a second visit" do
    appointment = complete_visit("20")

    assert_no_difference -> { Visit.count } do
      appointment.update!(visit_amount: "45")
    end

    assert_equal 4500, appointment.reload.visit.price_cents
    assert_equal 4500, Visit.usage_revenue_cents
  end
end
