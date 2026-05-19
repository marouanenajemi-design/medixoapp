class CreateDoctors < ActiveRecord::Migration[7.1]
  def change
    create_table :doctors do |t|
      t.string :name
      t.string :specialty
      t.string :phone
      t.time :work_start
      t.time :work_end
      t.references :clinic, null: false, foreign_key: true

      t.timestamps
    end
  end
end
