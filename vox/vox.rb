require 'mongoid'
require_relative 'audio_processor'

class Vox
  include Mongoid::Document
  include Mongoid::Timestamps
  include AudioProcessor

  field :comment,  type: String
  field :time,     type: Integer
  field :accepted, type: Boolean, default: true

  embeds_one :descriptor
  belongs_to :chain
  belongs_to :creator, class_name: 'User', inverse_of: :created_voxes

  has_one    :nex, class_name: "Vox", inverse_of: :pre
  belongs_to :pre, class_name: "Vox", inverse_of: :nex

  belongs_to :layer, inverse_of: :layer
  has_many :startls, class_name: 'Layer', inverse_of: :lstart, autosave: true
  has_many :endls,   class_name: 'Layer', inverse_of: :lend,   autosave: true

  def initialize(attrs={}, upload=nil, root_path=nil, options={})
    attrs['descriptor'] = persist(upload, root_path)

    super attrs

    sox_time!
    sox_process!
  end

  def persisted?
    !self.read_attribute('descriptor').nil?
  end

  def processed?
    self.persisted? && !self.read_attribute('descriptor').file_path_proc.nil?
  end

  def file_dir(root_path)
    @file_dir ||= File.join root_path, 'public', 'uploads', 'voxes', Time.now.strftime('%Y%m%d'), 'original'
  end

  def file_path(dir, name)
    @file_path ||= File.join dir, name
  end

  def file_path_p(original)
    return if original.nil?

    parts = original.split('/').map do |segment|
      if segment == 'original'
        'processed'
      else
        segment
      end
    end

    dir = File.join parts[0...-1]

    FileUtils.mkdir_p dir unless File.directory? dir

    File.join parts
  end

  # params ups:UploadedFile
  # returns FileDescriptor
  def persist(ups, root_path)
    return if ups.nil?

    if root_path.nil?
      Dir.chdir '..'
      root_path = Dir.pwd
    end

    # raise InvalidFileType, 'Requires mp3 file!' unless ups && ups.audio?

    file = ups.tempfile
    dir  = file_dir(root_path)
    path = file_path(dir, ups.filename)

    FileUtils.mkdir_p dir unless File.directory? dir

    written = File.open(path, 'wb') { |f| f.write file.read }

    if written > 0
      {
        file_name:      ups.filename,
        file_type:      ups.filetype,
        file_cat:       ups.filecat,
        file_ext:       ups.fileext,
        file_path:      path,
        file_path_orig: path
      }
    else
      raise FileNotWritten, 'Something bad happened!'
    end
  end

  class InvalidFileType < StandardError; end
  class FileNotWritten < StandardError; end
end
