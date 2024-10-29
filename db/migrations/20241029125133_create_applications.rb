class CreateApplications < ActiveRecord::Migration[7.0]
  def change
    create_table :applications do |t|
      t.integer :user_id, null: false
      t.text :text, null: false
      t.text :commercial, :default => nil
      t.boolean :as_tll, :default => nil
      t.boolean :ready, :default => false
      t.boolean :processed, null: false, :default => false
      t.boolean :other_question, null: false, :default => false

      t.timestamps
    end
  end
end
