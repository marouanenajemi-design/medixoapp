class AddBillingFieldsToClinics < ActiveRecord::Migration[7.1]
  def change
    add_column :clinics, :plan, :string
    add_column :clinics, :trial_ends_at, :datetime
    add_column :clinics, :subscribed, :boolean
    add_column :clinics, :billing_customer_id, :string
    add_column :clinics, :billing_subscription_id, :string
  end
end
