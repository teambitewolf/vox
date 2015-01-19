require 'mongoid'

class User
  include Mongoid::Document
  include Mongoid::Timestamps

  embeds_many :cards
  has_many   :voxes

  has_many   :creations, class_name: 'VoxChain', inverse_of: :creator
  belongs_to :collaborations, class_name: 'VoxChain', inverse_of: :collaborators

  field :handle
  field :email

  validates_uniqueness_of :handle
end
