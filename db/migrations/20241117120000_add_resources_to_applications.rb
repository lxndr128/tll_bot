class AddResourcesToApplications < ActiveRecord::Migration[7.0]
  def change
    add_column :applications, :resources, :text, default: nil unless column_exists?(:applications, :resources)
  end
end
