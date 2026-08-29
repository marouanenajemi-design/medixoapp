class AddPricePerVisitToClinics < ActiveRecord::Migration[7.1]
  def change
    # NULL means "inherit the global price from billing_settings".
    add_column :clinics, :price_per_visit_cents, :integer, null: true
  end
end
