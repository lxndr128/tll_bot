class User < ActiveRecord::Base
  include AASM

  aasm do
    state :init, initial: true
    state :other_question, :announce_description, :on_whose_behalf, :commercial_or_not, :photos

    event :question do
      transitions from: :init, to: :other_question
    end

    event :question_sent do
      transitions from: :other_question, to: :sent
    end

    #---------------------------------------------------

    event :announce do
      transitions from: :init, to: :announce_description
    end

    event :behalf do
      transitions from: :announce_description, to: :on_whose_behalf
    end

    event :commercial do
      transitions from: :on_whose_behalf, to: :commercial_or_not
    end

    event :add_photos do
      transitions from: :commercial_or_not, to: :photos
    end

    #---------------------------------------------------

    event :back_to_start do
      transitions from: [:other_question, :announce_description, :on_whose_behalf, :commercial_or_not, :photos], to: :init
    end
  end

  has_many :applications
  has_many :questions
end
