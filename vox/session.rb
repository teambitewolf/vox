require 'mongoid'

class Session
  include Mongoid::Document
  include Mongoid::Timestamps

  def initialize

  end
end
