# Global monetization settings for the platform — a single row, edited by the
# Super Admin from Admin → Monetization. Individual clinics may override the
# price per visit (see Clinic#price_per_visit_cents / VisitBilling).
class BillingSetting < ApplicationRecord
  DEFAULT_PRICE_PER_VISIT_CENTS = 200
  DEFAULT_CURRENCY              = "EUR".freeze

  CURRENCIES = %w[EUR USD GBP MAD].freeze

  CURRENCY_SYMBOLS = {
    "EUR" => "€",
    "USD" => "$",
    "GBP" => "£",
    "MAD" => "MAD"
  }.freeze

  validates :price_per_visit_cents,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :currency, presence: true, inclusion: { in: CURRENCIES }

  # The one and only settings row. Created on first read so a fresh install
  # works without seeding; the singleton_guard unique index keeps it single.
  def self.current
    first || create!
  rescue ActiveRecord::RecordNotUnique
    first
  end

  # Parses a human amount ("2", "2.50", "2,50") into cents.
  # Returns nil for blank or non-numeric input so callers can reject it.
  def self.to_cents(amount)
    return nil if amount.blank?

    normalized = amount.to_s.strip.tr(",", ".")
    return nil unless normalized.match?(/\A\d+(\.\d{1,2})?\z/)

    (normalized.to_d * 100).round
  end

  def self.symbol_for(currency)
    CURRENCY_SYMBOLS.fetch(currency.to_s, currency.to_s)
  end

  def price_per_visit
    price_per_visit_cents.to_d / 100
  end

  # Lets the admin form submit euros while the column stays in cents.
  def price_per_visit=(amount)
    self.price_per_visit_cents = self.class.to_cents(amount)
  end

  def currency_symbol
    self.class.symbol_for(currency)
  end
end
