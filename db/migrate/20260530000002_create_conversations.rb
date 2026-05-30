class CreateConversations < ActiveRecord::Migration[7.1]
  def change
    create_table :conversations do |t|
      t.references :clinic, null: false, foreign_key: true
      t.string :title

      t.timestamps
    end

    add_index :conversations, [:clinic_id, :created_at]
  end
end
