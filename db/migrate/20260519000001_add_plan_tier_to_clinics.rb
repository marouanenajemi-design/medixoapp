class AddPlanTierToClinics < ActiveRecord::Migration[7.1]
  def change
    add_column :clinics, :plan_tier, :string, default: "starter", null: false
  end
end
