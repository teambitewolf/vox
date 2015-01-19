require 'mongoid'

class Card
  include Mongoid::Document
  include Mongoid::Timestamps

  field :title
  field :comment

  has_one :descriptor

  belongs_to :user
  belongs_to :vox_chain
end
