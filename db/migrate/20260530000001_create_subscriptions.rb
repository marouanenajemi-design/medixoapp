class CreateSubscriptions < ActiveRecord::Migration[7.1]
  def change
    create_table :subscriptions do |t|
      t.references :clinic, null: false, foreign_key: true

      t.string :lemon_subscription_id, null: false
      t.string :lemon_customer_id
      t.string :lemon_order_id
      t.string :lemon_product_id
      t.string :lemon_variant_id

      t.string :status,    null: false, default: "active"
      t.string :plan_tier, null: false, default: "starter"

      t.datetime :renews_at
      t.datetime :ends_at
      t.datetime :trial_ends_at

      t.timestamps
    end

    add_index :subscriptions, :lemon_subscription_id, unique: true
    add_index :subscriptions, :lemon_customer_id
    add_index :subscriptions, :status
  end
end
