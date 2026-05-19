require "test_helper"

class PrescriptionItemTest < ActiveSupport::TestCase
  test "requires medicine name" do
    item = PrescriptionItem.new(
      prescription: prescriptions(:one),
      medicine_name: nil,
      dosage: "10mg",
      frequency: "Once daily",
      duration: "7 days",
      instructions: "After food"
    )

    assert_not item.valid?
    assert_includes item.errors[:medicine_name], "can't be blank"
  end
end
