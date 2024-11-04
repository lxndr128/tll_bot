class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :users do |t|
      t.bigint :tg_id, null: false
      t.string :username, null: false
      t.string :aasm_state, null: false, :default => 'init'
      t.boolean :admin, null: false, :default => false

      t.timestamps
    end
  end
end
