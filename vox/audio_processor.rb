require 'cocaine'

module AudioProcessor
  def sox_time!(rerun=false)
    if ((self.time.nil? || self.time.to_i == 0) || rerun == true) && self.descriptor
      cmd   = Cocaine::CommandLine.new('sox', check_wristwatch)
      path  = self.descriptor.file_path
      match = /(\d+\.\d+)/.match cmd.run(in: path)
      self.time = match.captures.first.to_f*1000.to_i
    end
  end

  def sox_process!(options={})
    return if self.processed? || self.descriptor.nil?

    cmd    = Cocaine::CommandLine.new('sox', put_on_your_sox)
    input  = self.descriptor.file_path_orig
    output = self.file_path_p input

    cmd.run(in: input, out: output)

    self.descriptor.file_path_proc = output
    self.descriptor.file_path = output
  end

  def splice!(root_path=nil, options={})
    if self.voxes.count > 0
      if self.voxes.count != self.count
        cmd    = Cocaine::CommandLine.new('sox', have_another_splice)
        output = file_path(root_path)
        cmd.run(out: output)

        self.count = voxes.count

        if self.descriptor
          self.descriptor.file_path = output
          self.descriptor.file_path_orig = output
        else
          self.descriptor = Descriptor.new({
            file_name: output.split('/').last,
            file_type: 'audio/mp3',
            file_cat:  'audio',
            file_ext:  'mp3',
            file_path: output,
            file_path_orig: output
          })
        end

        sox_time! true
      end
    else
      self.time = 0 if !self.time.nil?
    end

    self.save
  end

  def mix!
    if self.respond_to?(:layers) && self.layers.count > 0
      output = self.file_path_p self.descriptor.file_path

      self.layers.each do |layer|
        cmd    = Cocaine::CommandLine.new('sox', merge_conflict)
        input  = pad_trim_vol layer
        cmd.run(in: input, main: self.descriptor.file_path_orig, out: output)
        layer.applied = true
      end

      self.descriptor.file_path = output
      self.descriptor.file_path_proc = output
      self.save
    end
  end

  # DON'T TRIM 0 0 IDIOT
  def pad_trim_vol(layer)
    start_time = self.breaks.select{|o| o[0].id == layer.lstart.id}.first[1].round 2
    time_between = self.time_between(layer.lstart, layer.lend).round 2
    trim = (layer.vox.time / 1000.00) < time_between ? " " : "trim 0 #{time_between} "
    volume = (layer.vol / 100.00).round 2
    "| sox #{layer.vox.descriptor.file_path_proc} -p #{trim}pad #{start_time} 0 vol #{volume}"
  end

  def merge_conflict
    cmd = []
    cmd << '-m'
    cmd << ':in'
    cmd << ':main'
    cmd << ':out'
    cmd.join(' ')
  end

  def have_another_splice
    cmd = []
    cmd << self.ordered_voxes.map {|v| v.descriptor.file_path}.join(' ')
    cmd << ':out'
    cmd << 'splice'
    cmd.join(' ')
  end

  def never_break_the_chain
    voxes.map {|v| v.descriptor.file_path}.join(' ')
  end

  def check_wristwatch
    cmd = []
    cmd << ':in'
    cmd << '-n stat'
    cmd << '2>&1'
    cmd << '|'
    cmd << 'grep'
    cmd << "'Length (seconds)'"
    cmd.join(' ')
  end

  def put_on_your_sox(nm=true, eq=true, cm=true)
    cmd = []
    cmd << ':in'
    cmd << '-c 1'
    cmd << '-C 128'
    cmd << ':out'
    cmd << 'riaa' if eq
    cmd << 'compand 0.3,1 6:-70,-60,-20 -10 -90 0.2' if cm
    cmd << 'norm' if nm
    cmd << 'vad reverse vad reverse'
    cmd.join(' ')
  end

  def splice
    new_filename = self.name ? name.downcase.gsub(' ', '_') : joined
    dst = Tempfile.new([new_filename, '.mp3'])
    dst.binmode

    if self.segments.where(accepted: true).count > 0
      begin
        file_cmd = Cocaine::CommandLine.new('sox', have_another_splice)
        file_cmd.run(out: File.expand_path(dst.path))

        time_cmd = Cocaine::CommandLine.new('sox', check_wristwatch)
        match = /(\d+\.\d+)/.match time_cmd.run(in: File.expand_path(dst.path))

        self.audio = dst
        self.time = match[0].to_i
        # self.time = Time.at(match[0].to_f).utc.strftime("%M:%S")
        self.save
      ensure
        dst.close
        dst.unlink
      end
    end

    dst
  end
end
