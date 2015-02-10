require 'mongoid'

class Deck
  include Mongoid::Document
  include Mongoid::Timestamps

  has_many :cards

  belongs_to :chain
  belongs_to :creator, class_name: 'User', inverse_of: :created_decks
  belongs_to :user

  field :name, type: String
end
