class AddAmountEnteredAtToVisits < ActiveRecord::Migration[7.1]
  def change
    # Set when the amount on a visit was typed by a person at the point of sale.
    # NULL means the visit fell back to the suggested default price, which lets
    # the UI flag "not priced yet" without ever changing a stored amount.
    add_column :visits, :amount_entered_at, :datetime, null: true
  end
end
