class CreateClinics < ActiveRecord::Migration[7.1]
  def change
    create_table :clinics do |t|
      t.string :name
      t.string :address
      t.string :phone
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
