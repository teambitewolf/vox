require 'mongoid'
require_relative 'audio_processor'

class Chain
  include Mongoid::Document
  include Mongoid::Timestamps
  include AudioProcessor

  field :title,   type: String
  field :comment, type: String
  field :time,    type: Integer, default: 0
  field :count,   type: Integer, default: 0

  has_many :voxes, autosave: true
  has_many :layers, autosave: true
  has_many :invitations, autosave: true

  has_many :cards
  has_many :decks

  embeds_one :descriptor

  belongs_to :creator, class_name: 'User', inverse_of: :created_chains
  has_and_belongs_to_many :collaborators, class_name: 'User', inverse_of: :collaborations

  validates_presence_of :title

  def display_time
    hours = (self.time / 1000.00) / (60 * 60)
    split = hours.to_s.split('.')
    hours = split[0].to_i
    minutes = "0.#{split[1]}".to_f * 60
    split = minutes.to_s.split('.')
    minutes = split[0].to_i
    seconds = ("0.#{split[1]}".to_f * 60).to_i
    "#{sprintf('%02d', hours)}:#{sprintf('%02d', minutes)}:#{sprintf('%02d', seconds)}"
  end

  def file_dir(root_path=nil)
    @file_dir ||= begin
      root_dir = root_path || Dir.chdir('..') { Dir.pwd }
      File.join root_dir, 'public', 'uploads', 'chains', Time.now.strftime('%Y%m%d'), 'original'
    end
  end

  def file_path(root_path)
    @file_path ||= begin
      dir = file_dir(root_path)
      FileUtils.mkdir_p dir unless File.directory? dir
      path = File.join dir, "#{title}.mp3"
      FileUtils.touch(path) unless File.exist? path
      path
    end
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

  def add(new_thing)
    if new_thing.is_a? Vox
      add_vox(new_thing)
    elsif new_thing.is_a? Card
      add_card(new_thing)
    else
      raise 'That type of thing is weird.'
    end
  end

  def add_vox(new_vox)
    self.voxes << new_vox
    v = self.voxes.select{|v| v.nex == nil}.first
    v.nex = new_vox unless new_vox.id == v.id
    self
  end

  def add_card(new_card)
    self.cards << new_card
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

  def add_under(new_vox, start_vox, end_vox)
    if new_vox && self.voxes.include?(start_vox) && self.voxes.include?(end_vox)
      layer = Layer.create({
        vox:   new_vox,
        lstart: start_vox,
        lend:   end_vox
      })

      if layer.is_meaningful?
        self.layers << layer
        layer
      end
    end
  end

  def move_breaks_layers?(pos, move_vox, to_vox)
    if pos == :before
      # layer doesn't start at to_vox but ends at move_vox - *potentially* breaks layer
      # layer starts at to_vox and ends at move_vox - breaks layer
      ends_at_move  = self.layers.select {|layer| layer.lend == move_vox }
      start_and_end = self.layers.select {|layer| layer.lstart == to_vox && layer.lend == move_vox }

      if start_and_end.count > 0
        start_and_end.map {|layer| layer.id }
      elsif ends_at_move.count > 0
        ends_at_move.collect do |layer|
          binding.pry
          !self.comes_before? layer.lstart, to_move
        end.count > 0
      else
        false
      end
    elsif pos == :after
      # layer starts at move_vox and ends before to_vox - breaks layer
      # layer starts at to_vox and ends at move_vox - breaks layer
      starts_at_move = self.layers.select {|layer| layer.lstart == move_vox }
      start_and_end = self.layers.select {|layer| layer.lstart == move_vox && layer.lend == to_vox }

      if start_and_end.count > 0
        start_and_end.map {|layer| layer.id }
      elsif start_at_move.count > 0
        starts_at_move.collect do |layer|
          !self.comes_before? layer.lend, to_vox
        end.count > 0
      else
        false
      end
    end
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
       ordered = []
       while elem != nil do
         ordered << elem
         elem = elem.nex
       end
       ordered
     end
  end

  def breaks
    @breaks ||= begin
      time = 0
      ordered_voxes.reduce([]) do |m, v|
        m << [v, time / 1000.00]
        time += v.time
        m
      end
    end
  end

  def time_between(from_vox, to_vox)
    if comes_before? from_vox, to_vox
      time = from_vox.time
      elem = from_vox.nex
      while elem != nil do
        time += elem.time
        break if elem == to_vox
        elem = elem.nex
      end
      time / 1000.00
    end
  end

  def comes_before?(maybe_before, the_vox)
    if self.voxes.include?(the_vox) && self.voxes.include?(maybe_before)
      ordered_voxes.index{|v| v.id == maybe_before.id } < ordered_voxes.index{|v| v.id == the_vox.id}
    else
      false
    end
  end

  def in_order?(*voxes)
    voxes_ordered = ordered_voxes.reduce([]) do |arr, vox|
      if voxes.include? vox
        arr << vox
      else
        arr
      end
    end

    voxes == voxes_ordered
  end
end
