require 'mongoid'

class VoxImage
  includes Mongoid::Document
  includes Mongoid::Timestamps

  field :filename, type: String
  field :filepath, type: String
  field :filetype, type: String
  field :filecat,  type: String
  field :height, type: Integer
  field :width,  type: Integer

  embedded_in :vox_chain
  embedded_in :user
end
