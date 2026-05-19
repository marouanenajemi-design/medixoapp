require "test_helper"

class ClinicTest < ActiveSupport::TestCase
  test "requires basic clinic information" do
    clinic = Clinic.new(user: users(:three), name: "", address: "", phone: "")

    assert_not clinic.valid?
    assert_includes clinic.errors[:name], "can't be blank"
    assert_includes clinic.errors[:address], "can't be blank"
    assert_includes clinic.errors[:phone], "can't be blank"
  end
end
