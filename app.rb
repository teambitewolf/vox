require 'sinatra'
require 'omniauth'
require 'omniauth-twitter'
require 'pry'
require 'sinatra/reloader' if development?
require './vox/uploaded_file'
require './vox/vox'
require './vox/vox_chain'
require './vox/user'
require './vox/descriptor'
require './vox/card'
require './vox/session'
require './vox/layer'
require './vox/invitation'

configure do
  Mongoid.load! 'mongoid.yml'

  use Rack::Session::Cookie
  use OmniAuth::Builder do
    provider :developer unless production?
    provider :twitter, ENV['TWITTER_KEY'], ENV['TWITTER_SECRET']
  end
end

set :root, File.dirname(__FILE__)

set :request_method do |rm|
  condition do
    request.request_method == rm.to_s.upcase
  end
end

def current_user
  @current_user ||= User.where(id: session[:user_id]).first
end

def flash
  @flash ||= begin
    err = session[:errors]
    session[:errors] = nil
    err
  end
end

def flash=(vals)
  vals.each do |v|
    return unless v.is_a? String
  end

  session[:errors] = vals
end

before do
  auth = request.fullpath.include?('vox')
  redirect to '/login' if auth && current_user.nil?
end

before request_method: :post do
  @upload = UploadedFile.new(params['vox'].delete('upload')) if params['vox']
end

get '/login' do
  redirect to "/user_by_name/#{current_user.name}" if current_user
  haml :login
end

post '/auth/developer/callback' do
  user = User.where(email: request.env['omniauth.auth']['info']['email']).first

  if user
    session[:user_id] = user.id.to_s
  else
    user = User.new({
      handle: request.env['omniauth.auth']['info']['name'],
      email: request.env['omniauth.auth']['info']['email']
    })

    if user.save
      session[:user_id] = user.id.to_s
    else
      self.flash = user.errors.messages.map do |field, errors|
        errors.map do |err|
          "#{field.to_s} #{err.to_s}"
        end
      end.flatten
    end
  end

  redirect to "/user_by_name/#{user.handle}"
end

get '/logout' do
  session[:user_id] = nil
  redirect to '/login'
end

get '/users/:user_id' do
  @user = User.find params['user_id']

  if @user
    haml :user
  else
    redirect to '/error/something_happened'
  end
end

get '/user_by_name/:handle' do
  @user = User.where(handle: params['handle']).first

  if @user
    haml :user
  else
    redirect to '/error/something_happened'
  end
end

get '/voxes' do
  @voxes = VoxChain.all
  @voxes.to_json
end

get '/vox/new' do
  haml :new
end

get '/vox/:vox_id' do
  @vc = VoxChain.find params['vox_id']
  haml :vox
end

get '/vox/:chain_id/add' do
  @vc = VoxChain.find params['chain_id']
  haml :add
end

get '/vox/:vox_id/track' do
  vc = VoxChain.find params['vox_id']

  if vc.descriptor
    send_file(vc.descriptor.file_path, type: :mp3) and return
  else
    redirect to '/track_error'
  end
end

get '/vox/:chain_id/add_before/:vox_id' do
  @vc = VoxChain.find params['chain_id']

  if @vc
    @vox = @vc.voxes.find params['vox_id']

    if @vox
      haml :add_before
    end
  else
    redirect to '/error/something_happened'
  end
end

get '/vox/:chain_id/add_under/:start_vox/:end_vox' do
  @vc = VoxChain.find params['chain_id']

  if @vc
    @start = @vc.voxes.find params['start_vox']
    @end   = @vc.voxes.find params['end_vox']

    if @start && @end
      haml :add_under
    end
  else
    redirect to '/error/something_happened'
  end
end

get '/vox/:chain_id/add_under/:start_vox' do
  @vc = VoxChain.find params['chain_id']

  if @vc
    @start = @vc.voxes.find params['start_vox']

    if @start
      haml :half_under
    end
  else
    redirect to '/error/something_happened'
  end
end

get '/vox/:chain_id/move/:vox_id' do
  @vc = VoxChain.find params['chain_id']

  if @vc
    @vox = @vc.voxes.find params['vox_id']

    if @vox
      haml :move
    end
  else
    redirect to '/error/something_happened'
  end
end

get '/vox/:chain_id/ordered' do
  @vc = VoxChain.find params['chain_id']

  if @vc
    haml :ordered
  else
    redirect to '/error/something_happened'
  end
end

get '/invitations/new' do
  haml :invitation
end

get '/error/something_happened' do
  haml :error
end

post '/vox/invitations' do
  invitee = User.find params['invitee_id']
  invitor = User.find params['invitor_id']
  chain   = VoxChain.find params['chain_id']

  if !chain.collaborators.include?(invitee) && chain.collaborators.include?(invitor)
    invitation = Invitation.new({
      vox_chain: chain,
      invitor: invitor,
      invitee: invitee
    })
  end
end

post '/invitations/:invitation_id/accept' do
  invitation = Invitation.find params['invitation_id']
end

post '/invitations/:invitation/decline' do
  invitation = Invitation.find params['invitation_id']
end

post '/vox/:chain_id/add_under' do
  vc = VoxChain.find params['chain_id']

  if vc
    s = vc.voxes.find params['start_vox']
    e = vc.voxes.find params['end_vox']

    if s && e && params['vox']
      params['vox']['user'] = current_user
      vc.add_under Vox.new(params['vox'], @upload, settings.root), s, e
      vc.splice! settings.root
      vc.mix!
      redirect to "/vox/#{vc.id}" and return
    end
  end

  redirect to '/error/something_happened'
end

post '/vox/:chain_id/move' do
  vc = VoxChain.find params['chain_id']

  if vc
    move = vc.voxes.find params['move_vox']
    to   = vc.voxes.find params['to_vox']
    pos  = params['pos'].to_sym

    if move && to && pos
      vc.move pos, move, to
      vc.splice! settings.root
      redirect to "/vox/#{vc.id}" and return
    end
  end

  redirect to '/error/something_happened'
end

post '/vox/:chain_id/add_before' do
  vc = VoxChain.find params['chain_id']

  if vc
    v = vc.voxes.find params['vox_id']

    if v
      params['vox']['user'] = current_user
      vc.add_before v, Vox.new(params['vox'], @upload, settings.root)
      vc.splice! settings.root
      redirect to "/vox/#{vc.id}" and return
    end
  end

  redirect to '/error/something_happened'
end

post '/vox' do
  vc = VoxChain.new({
    title: (params['title'] || 'new'),
    comment: params['vox']['comment'],
    creator: current_user,
    collaborators: [current_user]
  })

  if vc.save
    params['vox']['user'] = current_user
    vc.add Vox.new params['vox'], @upload, settings.root
    vc.splice! settings.root
    redirect to "/vox/#{vc.id}" and return
  end

  redirect to '/error/something_happened'
end

post '/vox/:vox_id/add' do
  vc = VoxChain.find params['vox_id']

  if vc
    params['vox']['user'] = current_user
    vc.add Vox.new params['vox'], @upload, settings.root
    vc.splice! settings.root
    redirect to("/vox/#{vc.id}") and return
  end

  redirect to '/error/something_happened'
end

post '/vox/:chain_id/delete' do
  vc = VoxChain.find params['chain_id']

  if vc
    vc.remove params['vox_id']
    vc.splice! settings.root
    redirect to("/vox/#{vc.id}") and return
  end

  redirect to '/error/something_happened'
end
