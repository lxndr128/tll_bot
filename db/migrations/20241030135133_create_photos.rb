class CreatePhotos < ActiveRecord::Migration[7.0]
  def change
    create_table :photos do |t|
      t.text :file_id
      t.bigint :application_id

      t.timestamps
    end
  end
end
