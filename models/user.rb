class User < ActiveRecord::Base
  include AASM

  aasm do
    state :init, initial: true
    state :main_text, :on_whose_behalf, :commercial_or_not, :photos, :sent 
  end

  has_many :applications
end
