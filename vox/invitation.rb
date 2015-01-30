require 'mongoid'

class Invitation
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :invitor, class_name: 'User', inverse_of: :invitations
  belongs_to :invitee, class_name: 'User', inverse_of: :invited_to
  belongs_to :vox_chain
end
