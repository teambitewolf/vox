class UploadedFile
  attr_reader :file_name, :file_ext, :file_type, :file_cat, :temp_file

  # fetch from Sinatra upload params
  def initialize(attrs)
    return if attrs.nil?

    @file_name = attrs.fetch :filename
    @file_ext  = @file_name.split('.').last
    @file_type = attrs.fetch :type
    @file_cat  = @file_type.split('/').first
    @temp_file = attrs.fetch :tempfile
  end

  def nil?; empty?; end

  def empty?; @temp_file.nil?; end

  def audio?; file_type == 'audio/mp3'; end
end
