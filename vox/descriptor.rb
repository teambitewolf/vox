require 'mongoid'

class Descriptor
  include Mongoid::Document
  include Mongoid::Timestamps

  field :file_name
  field :file_ext
  field :file_type
  field :file_cat
  field :file_path

  field :file_path_orig
  field :file_path_proc

  field :file_path_mini
  field :file_path_small
  field :file_path_medium
  field :filed_pathlarge

  embedded_in :vox
  embedded_in :chain
  embedded_in :card
end
