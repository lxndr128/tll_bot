class User < ActiveRecord::Base
  include AASM

  aasm do
    state :init, initial: true
    state :other_question, :announce_description, :on_whose_behalf, :commercial_or_not, :photos, :sent

    event :question do
      transitions from: :init, to: :other_question
    end

    event :announce do
      transitions from: :init, to: :announce_description
    end

    event :question_sent do
      transitions from: :other_question, to: :sent
    end
  end

  has_many :applications
end
