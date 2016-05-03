require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "redcarpet"
require "yaml"
require "bcrypt"
require "fileutils"

configure do
  enable :sessions
  set :session_secret, 'super secret'
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def load_file_content(path)
  content = File.read(path)
  case File.extname(path)
  when ".txt"
    headers["Content-Type"] = "text-plain"
    content
  when ".md"
    erb render_markdown(content)
  end
end

def user_signed_in?
  session.key?(:username)
end

def require_signed_in_user
  unless user_signed_in?
    session[:message] = "You must be signed in to do that"
    redirect "/"
  end
end

def credentials_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
end

def load_user_credentials
  YAML.load_file(credentials_path)
end

def valid_credentials?(username, password)
  credentials = load_user_credentials

  if credentials.key?(username)
    bcrypt_password = BCrypt::Password.new(credentials[username])
    bcrypt_password == password
  else
    false
  end
end

get "/" do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map do |path|
    File.basename(path)
  end
  erb :index
end

get "/new" do
  require_signed_in_user

  erb :new
end

get "/users/signin" do
  erb :signin
end

get "/users/signup" do
  erb :signup
end

post "/users/signup" do
  username = params[:username]
  credentials = load_user_credentials

  if params[:password].size == 0 || username.size == 0
    session[:message] = "A username and password is required"
    erb :signup
  elsif credentials.key?(username)
    session[:message] = "Username taken. Please choose a new username"
    erb :signup
  else
    password = BCrypt::Password.create(params[:password])
    credentials[username] = password

    File.open(credentials_path, 'w') { |f| f.write credentials.to_yaml }
    session[:message] = "Account created. Please sign in."
    redirect "/"
  end
end

post "/users/signin" do
  username = params[:username]

  if valid_credentials?(username, params[:password])
    session[:username] = username
    session[:message] = "Welcome!"
    redirect "/"
  else
    session[:message] = "Invalid credentials"
    status 422
    erb :signin
  end
end

post "/users/signout" do
  session.delete(:username)
  session[:message] = "You have been signed out"
  redirect "/"
end

post "/create" do
  require_signed_in_user

  filename = params[:filename].to_s
  file_path = File.join(data_path, params[:filename])

  if filename.size == 0
    session[:message] = "A name is required"
    status 422
    erb :new
  elsif File.exist?(file_path)
    session[:message] = "File name in use. Choose a new name."
    status 422
    erb :new
  elsif ![".txt", ".md"].include?(File.extname(filename))
    session[:message] = "That file type is not supported"
    status 422
    erb :new
  else
    File.write(file_path, "")
    session[:message] = "#{params[:filename]} has been created"
    redirect "/"
  end
end

post "/copy" do
  require_signed_in_user

  filename = params[:filename].to_s
  file_path = File.join(data_path, params[:filename])

  if filename.size == 0
    session[:message] = "A name is required"
    status 422
    erb :copy
  elsif File.exist?(file_path)
    session[:message] = "File name in use. Choose a new name."
    status 422
    erb :copy
  elsif ![".txt", ".md"].include?(File.extname(filename))
    session[:message] = "That file type is not supported"
    status 422
    erb :copy
  else
    File.write(file_path, "")
    session[:message] = "#{params[:filename]} has been created"
    redirect "/"
  end
end

get "/:filename" do
  file_path = File.join(data_path, params[:filename])

  if File.exist?(file_path)
    load_file_content(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

get "/:filename/edit" do
  require_signed_in_user

  file_path = File.join(data_path, params[:filename])

  @filename = params[:filename]
  @content = File.read(file_path)

  erb :edit
end

post "/:filename" do
  require_signed_in_user

  file_path = File.join(data_path, params[:filename])

  File.write(file_path, params[:content])

  session[:message] = "#{params[:filename]} has been updated"
  redirect "/"
end

post "/:filename/delete" do
  require_signed_in_user

  file_path = File.join(data_path, params[:filename])
  File.delete(file_path)
  session[:message] = "#{params[:filename]} has been deleted"
  redirect "/"
end

get "/:filename/copy" do
  require_signed_in_user

  file_path = File.join(data_path, params[:filename])

  @filename = params[:filename]
  @content = File.read(file_path)

  erb :copy
end



