class CreatePrescriptionItems < ActiveRecord::Migration[7.1]
  def change
    create_table :prescription_items do |t|
      t.references :prescription, null: false, foreign_key: true
      t.string :medicine_name
      t.string :dosage
      t.string :frequency
      t.string :duration
      t.text :instructions

      t.timestamps
    end
  end
end
