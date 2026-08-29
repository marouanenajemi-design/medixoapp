require "test_helper"

class BillingSettingTest < ActiveSupport::TestCase
  test "current returns a single global settings row" do
    setting = BillingSetting.current

    assert setting.persisted?
    assert_equal setting.id, BillingSetting.current.id
    assert_equal 1, BillingSetting.count
  end

  test "current creates the row with sane defaults when none exists" do
    BillingSetting.delete_all

    setting = BillingSetting.current

    assert_equal BillingSetting::DEFAULT_PRICE_PER_VISIT_CENTS, setting.price_per_visit_cents
    assert_equal BillingSetting::DEFAULT_CURRENCY, setting.currency
  end

  test "to_cents parses human amounts" do
    assert_equal 200, BillingSetting.to_cents("2")
    assert_equal 250, BillingSetting.to_cents("2.50")
    assert_equal 250, BillingSetting.to_cents("2,50")
    assert_equal 0,   BillingSetting.to_cents("0")
    assert_equal 1250, BillingSetting.to_cents(" 12.5 ")
  end

  test "to_cents rejects blank and invalid amounts" do
    assert_nil BillingSetting.to_cents(nil)
    assert_nil BillingSetting.to_cents("")
    assert_nil BillingSetting.to_cents("abc")
    assert_nil BillingSetting.to_cents("-3")
    assert_nil BillingSetting.to_cents("1.234")
  end

  test "price_per_visit setter stores cents" do
    setting = BillingSetting.current
    setting.price_per_visit = "3.75"

    assert_equal 375, setting.price_per_visit_cents
    assert_equal BigDecimal("3.75"), setting.price_per_visit
  end

  test "an invalid price is rejected instead of silently becoming zero" do
    setting = BillingSetting.current
    setting.price_per_visit = "not a price"

    assert_not setting.valid?
    assert_includes setting.errors.attribute_names, :price_per_visit_cents
  end

  test "rejects unknown currencies" do
    setting = BillingSetting.current
    setting.currency = "XYZ"

    assert_not setting.valid?
  end
end
