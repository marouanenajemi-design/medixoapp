class AddBookingFields < ActiveRecord::Migration[7.1]
  def change
    add_column :appointments, :source,        :string, default: "clinic", null: false
    add_column :appointments, :patient_email,  :string
    add_column :patients,     :email,          :string
  end
end
