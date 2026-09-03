require "test_helper"

# Covers the prescription workflow end to end. Before the
# `before_validation :discard_blank_prescription_it` typo was fixed, every one
# of these raised NoMethodError, so creating or editing a prescription was
# impossible in the running app.
class PrescriptionWorkflowTest < ActionDispatch::IntegrationTest
  setup do
    @owner   = users(:one)
    @clinic  = clinics(:one)
    @clinic.update!(trial_ends_at: 10.days.from_now)
    @doctor  = doctors(:one)
    @patient = patients(:one)
    sign_in_as(@owner)
  end

  def base_params(items)
    {
      prescription: {
        prescription_date: Date.current,
        diagnosis: "Seasonal allergy",
        notes: "Review in two weeks",
        doctor_id: @doctor.id,
        patient_id: @patient.id,
        prescription_items_attributes: items
      }
    }
  end

  def blank_item
    { medicine_name: "", dosage: "", frequency: "", duration: "", instructions: "" }
  end

  def valid_item(name = "Cetirizine")
    { medicine_name: name, dosage: "10mg", frequency: "Once daily",
      duration: "7 days", instructions: "After food" }
  end

  # ── Create ────────────────────────────────────────────────────────────────

  test "a prescription with valid items can be created" do
    assert_difference -> { Prescription.count }, 1 do
      post prescriptions_url, params: base_params("0" => valid_item)
    end

    prescription = Prescription.order(:id).last

    assert_redirected_to prescription_path(prescription, locale: current_locale)
    assert_equal "Seasonal allergy", prescription.diagnosis
    assert_equal ["Cetirizine"], prescription.prescription_items.map(&:medicine_name)
  end

  test "several valid items are all saved" do
    post prescriptions_url, params: base_params(
      "0" => valid_item("Cetirizine"),
      "1" => valid_item("Ibuprofen")
    )

    assert_equal %w[Cetirizine Ibuprofen],
                 Prescription.order(:id).last.prescription_items.order(:id).map(&:medicine_name)
  end

  test "blank medicine rows are discarded instead of raising" do
    assert_difference -> { Prescription.count }, 1 do
      post prescriptions_url, params: base_params(
        "0" => valid_item,
        "1" => blank_item,
        "2" => blank_item
      )
    end

    prescription = Prescription.order(:id).last

    assert_equal 1, prescription.prescription_items.count
    assert_equal "Cetirizine", prescription.prescription_items.first.medicine_name
  end

  test "a prescription made only of blank rows saves with no items" do
    assert_difference -> { Prescription.count }, 1 do
      post prescriptions_url, params: base_params("0" => blank_item)
    end

    assert_equal 0, Prescription.order(:id).last.prescription_items.count
  end

  test "a missing prescription date is still rejected cleanly" do
    assert_no_difference -> { Prescription.count } do
      params = base_params("0" => valid_item)
      params[:prescription][:prescription_date] = ""
      post prescriptions_url, params: params
    end

    assert_response :unprocessable_entity
  end

  # ── Edit ──────────────────────────────────────────────────────────────────

  test "an existing prescription can be edited" do
    post prescriptions_url, params: base_params("0" => valid_item)
    prescription = Prescription.order(:id).last
    item = prescription.prescription_items.first

    patch prescription_url(prescription), params: base_params(
      "0" => valid_item("Loratadine").merge(id: item.id)
    ).deep_merge(prescription: { diagnosis: "Updated diagnosis" })

    assert_redirected_to prescription_path(prescription, locale: current_locale)
    prescription.reload

    assert_equal "Updated diagnosis", prescription.diagnosis
    assert_equal ["Loratadine"], prescription.prescription_items.map(&:medicine_name)
  end

  test "blanking an existing medicine row removes it on save" do
    post prescriptions_url, params: base_params("0" => valid_item)
    prescription = Prescription.order(:id).last
    item = prescription.prescription_items.first

    assert_difference -> { prescription.prescription_items.count }, -1 do
      patch prescription_url(prescription),
            params: base_params("0" => blank_item.merge(id: item.id))
      prescription.reload
    end
  end

  test "the new and edit pages render" do
    post prescriptions_url, params: base_params("0" => valid_item)
    prescription = Prescription.order(:id).last

    get new_prescription_url
    assert_response :success

    get edit_prescription_url(prescription)
    assert_response :success

    get prescription_url(prescription)
    assert_response :success
  end

  # ── Tenant isolation (unchanged behaviour, guarded) ───────────────────────

  test "another clinic's prescription cannot be edited" do
    foreign = Prescription.create!(clinic: clinics(:two), doctor: doctors(:two),
                                   patient: patients(:two), prescription_date: Date.current)

    patch prescription_url(foreign), params: base_params("0" => valid_item)

    assert_response :not_found
    assert_nil foreign.reload.diagnosis
  end

  # ── EN / FR ───────────────────────────────────────────────────────────────

  test "the flow works in French and shows no raw translation keys" do
    post prescriptions_url(locale: :fr), params: base_params("0" => valid_item)
    prescription = Prescription.order(:id).last

    assert_redirected_to prescription_path(prescription, locale: :fr)
    follow_redirect!

    assert_response :success
    assert_no_match(/translation missing/i, response.body)
    assert_match I18n.t("flash.prescriptions.created", locale: :fr), response.body

    # The forms themselves must render in French too.
    get new_prescription_url(locale: :fr)
    assert_response :success
    assert_no_match(/translation missing/i, response.body)

    get edit_prescription_url(prescription, locale: :fr)
    assert_response :success
    assert_no_match(/translation missing/i, response.body)
  end

  test "the English flash is shown in English" do
    post prescriptions_url, params: base_params("0" => valid_item)
    follow_redirect!

    assert_response :success
    assert_no_match(/translation missing/i, response.body)
    assert_match I18n.t("flash.prescriptions.created", locale: :en), response.body
  end
end
