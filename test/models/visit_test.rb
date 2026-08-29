require "test_helper"

class VisitTest < ActiveSupport::TestCase
  setup do
    @clinic  = clinics(:one)
    @doctor  = doctors(:one)
    @patient = patients(:one)
  end

  def build_visit(attributes = {})
    Visit.new({
      clinic:      @clinic,
      patient:     @patient,
      doctor:      @doctor,
      occurred_on: Date.current,
      source:      "appointment",
      price_cents: 200,
      currency:    "EUR"
    }.merge(attributes))
  end

  test "is valid with the expected attributes" do
    assert build_visit.valid?
  end

  test "requires a clinic, a date and a known source" do
    assert_not build_visit(clinic: nil).valid?
    assert_not build_visit(occurred_on: nil).valid?
    assert_not build_visit(source: "guesswork").valid?
    assert_not build_visit(price_cents: -1).valid?
  end

  test "the same appointment can only be billed once" do
    appointment = appointments(:one)

    assert build_visit(appointment: appointment).save

    duplicate = build_visit(appointment: appointment)

    assert_not duplicate.valid?
    assert_includes duplicate.errors.attribute_names, :appointment_id
  end

  test "the database rejects a duplicate even when validations are skipped" do
    appointment = appointments(:one)
    build_visit(appointment: appointment).save!

    assert_raises(ActiveRecord::RecordNotUnique) do
      Visit.insert!({
        clinic_id:      @clinic.id,
        appointment_id: appointment.id,
        occurred_on:    Date.current,
        source:         "appointment",
        price_cents:    200,
        currency:       "EUR",
        created_at:     Time.current,
        updated_at:     Time.current
      })
    end
  end

  test "cannot reference another clinic's records" do
    visit = build_visit(clinic: clinics(:two))

    assert_not visit.valid?
    assert_includes visit.errors.attribute_names, :patient
    assert_includes visit.errors.attribute_names, :doctor
  end

  test "voiding removes it from billable without deleting it" do
    visit = build_visit
    visit.save!

    assert_includes Visit.billable, visit

    visit.void!

    assert visit.persisted?
    assert_not visit.billable?
    assert_not_includes Visit.billable, visit
    assert_includes Visit.voided, visit

    visit.restore!

    assert visit.billable?
    assert_includes Visit.billable, visit
  end

  test "in_period filters by the date the visit happened" do
    this_month = build_visit(occurred_on: Date.current)
    this_month.save!
    last_month = build_visit(occurred_on: 1.month.ago.to_date)
    last_month.save!

    period = Date.current.beginning_of_month..Date.current.end_of_month

    assert_includes Visit.in_period(period), this_month
    assert_not_includes Visit.in_period(period), last_month
  end

  test "usage revenue multiplies each clinic's visits by its own price" do
    BillingSetting.current.update!(price_per_visit_cents: 200)
    clinics(:two).update!(price_per_visit_cents: 500)

    2.times { build_visit.save! }
    Visit.create!(clinic: clinics(:two), occurred_on: Date.current, source: "appointment",
                  price_cents: 500, currency: "EUR")

    # 2 × €2.00 (global) + 1 × €5.00 (override)
    assert_equal 900, Visit.usage_revenue_cents
  end

  test "usage revenue ignores voided visits" do
    BillingSetting.current.update!(price_per_visit_cents: 200)
    build_visit.save!

    voided = build_visit
    voided.save!
    voided.void!

    assert_equal 200, Visit.usage_revenue_cents
  end

  test "usage revenue is zero without visits" do
    assert_equal 0, Visit.usage_revenue_cents
  end
end
