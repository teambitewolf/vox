require 'mini_magick'

module ImageProcessor
#   def small!
#     image = MiniMagick::Image.open self.descriptor.file_path
#     image.format 'png'
#     image.combine_options do |c|
#       c.thumbnail '150x150<'
#       c.gravity 'center'
#       c.extent '150x150'
#     end
#     image_path = file_path_for_size self.descriptor.file_path, 'small'
#     image.write image_path
#
#     self.descriptor.file_path_small = image_path
#   end

  def small!
    image = MiniMagick::Image.open self.descriptor.file_path
    image.resize options_for_resize image, 150
    image.crop options_for_crop image, 150
    image.format 'png'
    image_path = file_path_for_size self.descriptor.file_path, 'small'
    image.write image_path
    self.descriptor.file_path_small = image_path
  end

  def file_path_for_size(original, size)
    parts = original.split('/').map do |segment|
      if segment == 'original'
        size
      else
        segment
      end
    end

    dir = File.join parts[0...-1]
    FileUtils.mkdir_p dir unless File.directory? dir
    File.join parts
  end

  def options_for_resize(image, size)
    width = image.width
    height = image.height

    if width > height || width == height
      "x#{size}"
    else
      "#{size}x"
    end
  end

  def options_for_crop(image, size)
    crop_x = (image.width / 2) - (size / 2)
    crop_y = (image.height / 2) - (size / 2)

    "#{size}x#{size}+#{crop_x > 0 ? crop_x : 0}+#{crop_y > 0 ? crop_y : 0}"
  end
end
