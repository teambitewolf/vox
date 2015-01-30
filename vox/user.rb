require 'mongoid'

class User
  include Mongoid::Document
  include Mongoid::Timestamps

  embeds_many :cards
  has_many   :voxes

  has_many :creations, class_name: 'VoxChain', inverse_of: :creator
  has_and_belongs_to_many :collaborations, class_name: 'VoxChain', inverse_of: :collaborators

  has_many :invitations, class_name: 'Invitation', inverse_of: :invitor, autosave: true
  has_many :invited_to, class_name: 'Invitation', inverse_of: :invitee, autosave: true

  field :handle
  field :email

  validates_uniqueness_of :handle
end
