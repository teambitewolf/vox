class UploadedFile
  attr_reader :filename, :fileext, :filetype, :filecat, :tempfile

  def initialize(attrs)
    return if attrs.nil?

    @filename = attrs.fetch :filename
    @fileext  = filename.split('.').last
    @filetype = attrs.fetch :type
    @filecat  = filetype.split('/').first
    @tempfile = attrs.fetch :tempfile
  end

  def nil?
    empty?
  end

  def empty?
    tempfile.nil?
  end

  def audio?
    filetype == 'audio/mp3'
  end
end
