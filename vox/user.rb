require 'mongoid'

class User
  include Mongoid::Document
  include Mongoid::Timestamps

  has_many :cards
  has_many :decks
  has_many :voxes

  has_many :created_chains, class_name: 'Chain', inverse_of: :creator, autosave: true
  has_many :created_cards,  class_name: 'Card',  inverse_of: :creator, autosave: true
  has_many :created_decks,  class_name: 'Deck',  inverse_of: :creator, autosave: true
  has_many :created_voxes,  class_name: 'User',  inverse_of: :creator, autosave: true

  has_and_belongs_to_many :collaborations, class_name: 'Chain', inverse_of: :collaborators

  has_many :invitations, class_name: 'Invitation', inverse_of: :invitor, autosave: true
  has_many :invited_to, class_name: 'Invitation', inverse_of: :invitee, autosave: true

  field :handle
  field :email

  validates_uniqueness_of :handle

  def add(new_thing)
    add_card(new_thing)
  end

  def add_card(new_card)
    self.cards << new_card
  end
end
