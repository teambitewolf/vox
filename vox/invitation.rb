require 'mongoid'

class Invitation
  include Mongoid::Document
  include Mongoid::Timestamps

  field :status, type: String, default: 'open'

  belongs_to :invitor, class_name: 'User', inverse_of: :invitations
  belongs_to :invitee, class_name: 'User', inverse_of: :invited_to
  belongs_to :chain

  validates_inclusion_of :status, in: ['open', 'accepted', 'declined']
end
