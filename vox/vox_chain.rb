require 'mongoid'

class VoxChain
  include Mongoid::Document
  include Mongoid::Timestamps
  include AudioProcessor

  field :title,   type: String
  field :comment, type: String
  field :time,    type: Integer, default: 0
  field :count,   type: Integer, default: 0

  has_many    :voxes
  embeds_many :cards
  embeds_one  :descriptor

  belongs_to :creator, class_name: 'User', inverse_of: :creations
  has_many   :collaborators, class_name: 'User', inverse_of: :collaborations

  def splice_dir(root_path=nil)
    @file_dir ||= begin
      root_dir = root_path || Dir.chdir('..') { Dir.pwd }
      File.join root_dir, 'public', 'uploads', 'chains', Time.now.strftime('%Y%m%d'), 'original'
    end
  end

  def splice_path(root_path)
    @file_path ||= begin
      dir = splice_dir(root_path)
      FileUtils.mkdir_p dir unless File.directory? dir
      path = File.join dir, "#{title}.mp3"
      FileUtils.touch(path) unless File.exist? path
      path
    end
  end

  def add(new_vox)
    self.voxes << new_vox
    v = self.voxes.select{|v| v.nex == nil}.first
    v.nex = new_vox unless new_vox.id == v.id
    self
  end

  def add_before(the_vox, new_vox)
    self.voxes << new_vox
    if the_vox.pre
      p = Vox.find(the_vox.pre)
      p.nex = new_vox
    end
    new_vox.nex = the_vox
    self
  end

  def move(pos, move_vox, to_vox)
    if self.voxes.include?(move_vox) && self.voxes.include?(to_vox) && [:before, :after].include?(pos)
      if move_vox.pre
        if move_vox.nex
          Vox.find(move_vox.pre).nex = Vox.find(move_vox.nex)
        else
          Vox.find(move_vox.pre).nex = nil
        end
      else
        if move_vox.nex
          Vox.find(move_vox.nex).pre = nil
        end
      end

      if pos == :before
        if to_vox.pre
          Vox.find(to_vox.pre).nex = move_vox
        else
          Vox.find(move_vox).pre = nil
        end

        Vox.find(move_vox).nex = to_vox
      elsif pos == :after
        if to_vox.nex
          Vox.find(move_vox).nex = Vox.find(to_vox.nex)
        else
          Vox.find(move_vox).nex = nil
        end

        Vox.find(to_vox).nex = move_vox
      end
    end

    self
  end

  def remove(vox_id)
    v = self.voxes.where(id: vox_id).first

    unless v.nil?
      if v.pre && self.voxes.include?(v.pre)
        if v.nex && self.voxes.include?(v.nex)
          Vox.find(v.pre).nex = Vox.find(v.nex)
        else
          v.pre = nil
        end
      else
        if v.nex && self.voxes.include?(v.nex)
          v.nex = nil
        end
      end

      self.voxes.delete(v)
    end

    self
  end

  def ordered_voxes
    @ordered_voxes ||= begin
       elem    = self.voxes.select { |v| v.pre == nil }.first
       ordered = [elem]

       while elem.nex != nil do
         ordered << elem.nex
         elem = elem.nex
       end

       ordered
     end
  end

  def breaks
    @breaks ||= begin
      time = 0
      ordered_voxes.reduce([]) do |m, v|
        time += v.time
        # let's create some fucking [[],[],[]] action
        m << [v, time / 1000.00]
      end
    end
  end

  def comes_before(the_vox, maybe_before)
    if self.voxes.include?(the_vox) && self.voxes.include?(maybe_before)
      ordered_voxes.index(the_vox) < ordered_voxes.index(maybe_before)
    else
      false
    end
  end
end
