require 'cocaine'

module AudioProcessor
  def sox_time!(rerun=false)
    if ((self.time.nil? || time.to_i == 0) || rerun == true) && self.descriptor
      cmd   = Cocaine::CommandLine.new('sox', check_wristwatch)
      path  = descriptor.file_path
      match = /(\d+\.\d+)/.match cmd.run(in: path)

      self.time = match.captures.first.to_f*1000.to_i
    end
  end

  # options: Hash :norm, :eq, :compress
  def sox_process!(options={})
    return if processed? || descriptor.nil?

    cmd    = Cocaine::CommandLine.new('sox', put_on_your_sox)
    input  = descriptor.file_path_orig
    output = file_path_p input

    cmd.run(in: input, out: output)

    self.descriptor.file_path_proc = output
    self.descriptor.file_path = output
  end

  def splice!(root_path=nil, options={})
    if self.voxes.count > 0
      if self.voxes.count != self.count
        cmd    = Cocaine::CommandLine.new('sox', have_another_splice)
        output = splice_path(root_path)
        cmd.run(out: output)

        self.count = voxes.count

        if self.descriptor
          self.descriptor.file_path = output
        else
          self.descriptor = Descriptor.new({
            file_name: output.split('/').last,
            file_type: 'audio/mp3',
            file_cat:  'audio',
            file_ext:  'mp3',
            file_path: output,
          })
        end

        sox_time! true
      else
        # ???
      end
    else
      self.time = 0 if !self.time.nil?
    end
  end

=begin
To combine mix and effects (pad, trim etc) use the following:

sox -m "|sox end.mp3 -p pad 6 0" start.mp3 output.mp3
The general pattern is:

sox -m input1 input2 ... inputN output
where inputX can be either a filename or a pipe in quotes

"|sox end.mp3 -p pad 6"
=end
  def merge!; self; end

  def merge_conflict
    cmd = []
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
