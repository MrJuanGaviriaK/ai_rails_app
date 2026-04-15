class AddDailyPriceToMineralPurchases < ActiveRecord::Migration[8.1]
  def change
    add_reference :mineral_purchases, :daily_price, null: true, foreign_key: { on_delete: :nullify }
  end
end
