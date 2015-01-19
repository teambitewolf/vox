require 'mongoid'

class Descriptor
  include Mongoid::Document

  field :file_name
  field :file_ext
  field :file_type
  field :file_cat
  field :file_path
  field :file_path_orig
  field :file_path_proc

  embedded_in :vox
end
