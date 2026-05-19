class CreatePatients < ActiveRecord::Migration[7.1]
  def change
    create_table :patients do |t|
      t.string :name
      t.string :phone
      t.integer :age
      t.string :gender
      t.text :notes
      t.references :clinic, null: false, foreign_key: true

      t.timestamps
    end
  end
end
