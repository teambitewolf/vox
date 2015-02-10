require 'mongoid'

class Layer
  include Mongoid::Document
  include Mongoid::Timestamps

  field :vol,     type: Integer, default: 50
  field :applied, type: Boolean, default: false

  belongs_to :chain

  has_one    :vox, inverse_of: :layer, autosave: true
  belongs_to :lstart, class_name: 'Vox', inverse_of: :startls
  belongs_to :lend,   class_name: 'Vox', inverse_of: :endls

  def is_meaningful?
    self.lstart.nex == self.lend
  end
end
