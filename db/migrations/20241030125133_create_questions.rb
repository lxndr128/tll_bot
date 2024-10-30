class CreateQuestions < ActiveRecord::Migration[7.0]
  def change
    create_table :questions do |t|
      t.integer :user_id, null: false
      t.text :text
      t.boolean :ready, :default => false
      t.boolean :processed, null: false, :default => false

      t.timestamps
    end
  end
end
