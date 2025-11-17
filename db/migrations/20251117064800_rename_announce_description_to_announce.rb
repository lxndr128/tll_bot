class RenameAnnounceDescriptionToAnnounce < ActiveRecord::Migration[7.0]
  def change
    # Update any users stuck in announce_description state to announce
    User.where(aasm_state: 'announce_description').update_all(aasm_state: 'announce')
  end
end
