class CreateApplications < ActiveRecord::Migration[7.0]
  def change
    create_table :applications do |t|
      t.integer :user_id, null: false
      t.text :text
      t.text :commercial, :default => nil
      t.boolean :as_tll, :default => nil
      t.boolean :ready, :default => false
      t.boolean :processed, null: false, :default => false
      t.integer :processed_by
      t.integer :message_id, null: false

      t.timestamps
    end
  end
end
