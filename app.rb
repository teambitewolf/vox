require 'sinatra'
require 'omniauth'
require 'omniauth-twitter'
require 'pry'
require 'sinatra/reloader' if development?
require './vox/uploaded_file'
require './vox/vox'
require './vox/chain'
require './vox/user'
require './vox/descriptor'
require './vox/card'
require './vox/deck'
require './vox/layer'
require './vox/invitation'

configure do
  Mongoid.load! 'mongoid.yml'

  use Rack::Session::Cookie, secret: 'musubi'
  use OmniAuth::Builder do
    provider :developer unless production?
    provider :twitter, ENV['TWITTER_KEY'], ENV['TWITTER_SECRET']
  end
end

helpers do
  def polymorphic_url(elems)
    return unless elems.is_a? Array

    elems.reduce('') do |url, elem|
      if elem.is_a?(String) || elem.is_a?(Fixnum)
        url << "/#{elem}"
      else
        url << "/#{elem.class.to_s.downcase.pluralize}/#{elem.id}"
      end
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
end

set :root, File.dirname(__FILE__)

set :request_method do |rm|
  condition do
    request.request_method == rm.to_s.upcase
  end
end

before do
  auth = request.fullpath.include?('chains')
  redirect to '/login' if auth && current_user.nil?
end

before request_method: :post do
  if params['vox'] || params['card']
    @upload = UploadedFile.new (params['vox'] || params['card']).delete 'upload'
  end
end

get '/error/something_happened' do
  haml :error
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
    haml :'users/show'
  else
    redirect to '/error/something_happened'
  end
end

get '/users.json' do
  content_type :json
  User.all.to_json
end

get '/user_by_name/:handle' do
  @user = User.where(handle: params['handle']).first

  if @user
    haml :'users/show'
  else
    redirect to '/error/something_happened'
  end
end

get '/chains' do
  @voxes = Chain.all
  @voxes.to_json
end

get '/chains/new' do
  haml :'chains/new'
end

get '/chains/:chain_id' do
  @vc = Chain.find params['chain_id']
  haml :'chains/show'
end

get '/:owner/:owner_id/decks' do
  @owner = params['owner'].classify.constantize.find params['owner_id']
  haml :'decks/index'
end

get '/:owner/:owner_id/decks/new' do
  @owner = params['owner'].classify.constantize.find params['owner_id']
  haml :'decks/new'
end

post '/:owner/:owner_id/decks' do
  owner = params['owner'].classify.constantize.find params['owner_id']

  if owner
    params['deck']['creator'] = current_user

    owner.decks << Deck.new(params['deck'])

    if owner.save
      redirect to polymorphic_url([owner, 'cards']) and return
    end
  end

  redirect to '/error/something_happened'
end

get '/:owner/:owner_id/cards' do
  @owner = params['owner'].classify.constantize.find params['owner_id']
  haml :'cards/index'
end

get '/:owner/:owner_id/cards/new' do
  @owner = params['owner'].classify.constantize.find params['owner_id']
  haml :'cards/new'
end

post '/:owner/:owner_id/cards' do
  owner = params['owner'].classify.constantize.find params['owner_id']

  if owner
    params['card']['creator'] = current_user
    card = Card.new params['card'], @upload, settings.root

    if owner.respond_to? :add
      owner.add card
    else
      owner.cards << card
    end

    if owner.save
      redirect to polymorphic_url([owner, 'cards']) and return
    end
  end

  redirect to '/error/something_happened'
end

get '/chains/:chain_id/cards' do
  @vc = Chain.find params['chain_id']
  haml :'cards/show'
end

get '/chains/:chain_id/voxes/new' do
  @vc = Chain.find params['chain_id']
  haml :'voxes/new'
end

get '/:owner/:owner_id/cards/:card_id/image/:size' do
  owner = params['owner'].classify.constantize.find params['owner_id']

  if owner
    card = owner.cards.find params['card_id']

    if card && card.descriptor
      if params['size'] == 'original'
        send_file(card.descriptor.file_path, type: :jpg) and return
      elsif params['size'] == 'small'
        if card.descriptor.file_path_small
          send_file(card.descriptor.file_path_small, type: :png) and return
        else
          send_file(card.descriptor.file_path, type: :jpg) and return
        end
      end
    else
      redirect to '/image_error'
    end
  end
end

get '/chains/:chain_id/track' do
  vc = Chain.find params['chain_id']

  if vc.descriptor
    send_file(vc.descriptor.file_path, type: :mp3) and return
  else
    redirect to '/track_error'
  end
end

get '/chains/:chain_id/add_before/:vox_id' do
  @vc = Chain.find params['chain_id']

  if @vc
    @vox = @vc.voxes.find params['vox_id']

    if @vox
      haml :add_before
    end
  else
    redirect to '/error/something_happened'
  end
end

get '/chains/:chain_id/add_under/:start_vox/:end_vox' do
  @vc = Chain.find params['chain_id']

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

get '/chains/:chain_id/add_under/:start_vox' do
  @vc = Chain.find params['chain_id']

  if @vc
    @start = @vc.voxes.find params['start_vox']

    if @start
      haml :half_under
    end
  else
    redirect to '/error/something_happened'
  end
end

get '/chains/:chain_id/move/:vox_id' do
  @vc = Chain.find params['chain_id']

  if @vc
    @vox = @vc.voxes.find params['vox_id']

    if @vox
      haml :move
    end
  else
    redirect to '/error/something_happened'
  end
end

get '/chains/:chain_id/ordered' do
  @vc = Chain.find params['chain_id']

  if @vc
    haml :ordered
  else
    redirect to '/error/something_happened'
  end
end

get '/chains/:chain_id/layers/:layer_id/edit' do
  @vc = Chain.find params['chain_id']

  if @vc
    @layer = @vc.layers.find params['layer_id']

    if @layer
      haml :'layers/edit'
    end
  end
end

get '/chains/:chain_id/invitations/new' do
  @vc = Chain.find params['chain_id']

  if @vc
    haml :'invitations/new'
  end
end

get '/users/:user_id/invitations' do
  @user = User.find params['user_id']

  @open     = @user.invitations.where status: 'open'
  @accepted = @user.invitations.where status: 'accepted'
  @declined = @user.invitations.where status: 'declined'

  @open_invites     = @user.invited_to.where status: 'open'
  @accepted_invites = @user.invited_to.where status: 'accepted'
  @declined_invites = @user.invited_to.where status: 'declined'

  if @user
    haml :'invitations/index'
  end
end

post '/invitations/:invitation_id/accept' do
  invitation = Invitation.find params['invitation_id']

  if invitation
    invitation.chain.collaborators << invitation.invitee
    invitation.status = 'accepted'
    invitation.chain.save
  else
    self.flash = ['failed to update invitation']
  end

  redirect to "/users/#{current_user.id}"
end

post '/invitations/:invitation_id/decline' do
  invitation = Invitation.find params['invitation_id']

  if invitation
    invitation.status = 'declined'
    invitation.save
  else
    self.flash = ['failed to update invitation']
  end

  redirect to "/users/#{current_user.id}"
end

post '/chains/:chain_id/invitations' do
  chain   = Chain.find params['chain_id']
  invitor = User.find  params['invitation']['invitor_id']
  invitee = User.find_by handle: params['invitation']['invitee_handle']

  if !chain.collaborators.include?(invitee) && chain.creator == invitor
    invitation = Invitation.new({
      chain:   chain,
      invitor: invitor,
      invitee: invitee
    })

    if invitation.save
      redirect to "/chains/#{chain.id}"
    end
  end

  redirect to '/error/something_happened'
end

post '/chains/:chain_id/layers/:layer_id/edit' do
  vc = Chain.find params['chain_id']

  if vc
    layer = vc.layers.find params['layer_id']

    if layer
      layer.vol = params['volume']

      vc.splice!
      vc.mix!

      redirect to "/chains/#{vc.id}"
    end
  end
end

post '/chains/:chain_id/add_before' do
  vc = Chain.find params['chain_id']

  if vc
    v = vc.voxes.find params['vox_id']

    if v
      params['vox']['creator'] = current_user

      vc.add_before v, Vox.new(params['vox'], @upload, settings.root)
      vc.splice! settings.root
      redirect to "/chains/#{vc.id}" and return
    end
  end

  redirect to '/error/something_happened'
end

post '/chains/:chain_id/add_under' do
  vc = Chain.find params['chain_id']

  if vc
    s = vc.voxes.find params['start_vox']
    e = vc.voxes.find params['end_vox']

    if s && e && params['vox']
      params['vox']['creator'] = current_user

      layer = vc.add_under Vox.new(params['vox'], @upload, settings.root), s, e

      if layer
        vc.splice! settings.root
        vc.mix!
        redirect to "/chains/#{vc.id}" and return
      end
    end
  end

  redirect to '/error/something_happened'
end

post '/chains/:chain_id/move' do
  vc = Chain.find params['chain_id']

  if vc
    move = vc.voxes.find params['move_vox']
    to   = vc.voxes.find params['to_vox']
    pos  = params['pos'].to_sym

    if !vc.move_breaks_layers? pos, move, to
      vc.move pos, move, to
      vc.splice! settings.root
      redirect to "/chains/#{vc.id}" and return
    else
      self.flash = ['move will break layers']
      redirect to "/chains/#{vc.id}" and return
    end
  end

  redirect to '/error/something_happened'
end

post '/chains' do
  vc = Chain.new({
    title: (params['title'] || 'new'),
    comment: params['vox']['comment'],
    creator: current_user,
    collaborators: [current_user]
  })

  if vc.save
    params['vox']['creator'] = current_user

    vc.add Vox.new params['vox'], @upload, settings.root
    vc.splice! settings.root

    redirect to "/chains/#{vc.id}" and return
  end

  redirect to '/error/something_happened'
end

post '/chains/:chain_id/voxes' do
  vc = Chain.find params['chain_id']

  if vc
    params['vox']['creator'] = current_user

    vc.add Vox.new params['vox'], @upload, settings.root
    vc.splice! settings.root

    redirect to("/chains/#{vc.id}") and return
  end

  redirect to '/error/something_happened'
end

post '/chains/:chain_id/delete' do
  vc = Chain.find params['chain_id']

  if vc.destroy
    redirect to("/users/#{current_user.id}") and return
  end

  redirect to '/error/something_happened'
end

post '/chains/:chain_id/voxes/:vox_id/delete' do
  vc = Chain.find params['chain_id']

  if vc
    vc.remove params['vox_id']
    vc.splice! settings.root
    redirect to("/chains/#{vc.id}") and return
  end

  redirect to '/error/something_happened'
end
