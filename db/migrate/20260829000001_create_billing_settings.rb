class CreateBillingSettings < ActiveRecord::Migration[7.1]
  def up
    create_table :billing_settings do |t|
      # Singleton guard: only one row may ever exist (always 0 + unique index).
      t.integer :singleton_guard,       null: false, default: 0
      t.integer :price_per_visit_cents, null: false, default: 200
      t.string  :currency,              null: false, default: "EUR"

      t.timestamps
    end

    add_index :billing_settings, :singleton_guard, unique: true

    execute <<~SQL
      INSERT INTO billing_settings (singleton_guard, price_per_visit_cents, currency, created_at, updated_at)
      VALUES (0, 200, 'EUR', NOW(), NOW())
      ON CONFLICT (singleton_guard) DO NOTHING;
    SQL
  end

  def down
    drop_table :billing_settings
  end
end
