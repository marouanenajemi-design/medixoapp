namespace :billing do
  desc "Rebuild the billable-visit ledger from appointments (idempotent, safe to re-run)"
  task backfill_visits: :environment do
    result = VisitBillingService.backfill!
    puts "Billable visits — created: #{result[:created]}, voided: #{result[:voided]}, unchanged: #{result[:skipped]}"
  end

  desc "Show the current monetization settings and platform-wide visit usage"
  task status: :environment do
    setting = BillingSetting.current
    period  = Date.current.beginning_of_month..Date.current.end_of_month
    scope   = Visit.billable.in_period(period)

    puts "Suggested amount/visit:   #{setting.currency_symbol}#{format('%.2f', setting.price_per_visit)} (default only)"
    puts "Billing period:           #{period.first} → #{period.last}"
    puts "Billable visits (period): #{scope.count}"
    puts "Billable visits (total):  #{Visit.billable.count}"
    puts "Usage revenue (period):   #{setting.currency_symbol}#{format('%.2f', Visit.usage_revenue_cents(scope) / 100.0)}"
    puts "Clinics with an override: #{Clinic.where.not(price_per_visit_cents: nil).count}"
  end
end
