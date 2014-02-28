# encoding: utf-8
require 'multi_json'
require 'sinatra'
require 'sinatra/activerecord'

#
# connect to already existing postgresql database instance,
# establishing a connection with a DEFAULT database
# see also: http://amaras-tech.co.uk/article/111/Sinatra_ActiveRecord_DB_config_on_Heroku
#
ActiveRecord::Base.establish_connection(ENV['ESAMIANATOMIA_DB_URL'] || 'postgres://YOURUSERNAME:YOURPASSWORD@HOSTIPADDRESS/esamiAnatomia_development')


#
# declare tables to be used through Activerecord 
#
class Exam < ActiveRecord::Base
end

class User < ActiveRecord::Base
end

class Course < ActiveRecord::Base
end

#
# Establish a connection with a Model (a Table) belong to a database different from default 
# Declare some validations
#
class Note < ActiveRecord::Base
  # Establish a connection with a Model (a Table) belong to a database different from default 
  establish_connection(ENV['SAR_DB_URL'] || 'postgres://YOURUSERNAME:YOURPASSWORD@HOSTIPADDRESS/sar')

  # set table Name, in case in the existing datbase there is not a 'Rails naming' convention
  self.table_name = "notes"

  # validations a la Activerecord 
  validates :title, presence: true, length: { minimum: 3 }
  validates :body, presence: true
end

configure :development do
  enable :logging
end

mime_type :json, "application/json"

before do
  content_type :json 
end  

# export RACK_ENV=development
#set :environment, :development # :test, :production

=begin

# http://stackoverflow.com/questions/8772641/how-to-define-global-error-handler-for-json-in-sinatra
error do
  content_type :json
  status 400 # or whatever

  e = env['sinatra.error']
  {:result => 'error', :message => e.message}.json
end
=end

helpers do

  #
  # List of allowed API-KEYS: 
  # key are stored and read from a text file ( /db/app.keys ) without any encryption... 
  # BTW, that's just a demo, but please not if you have a small number of client, 
  # storing in memory API-KEYS could be super-fast solution!)
  # TODO: possibly use REDIS database to manage large numbers of keys.
  #
  # /db/app.keys file format:  
  # text file where every line has format {key}blank{comments}, by example: 
  # xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx UUID for user X, X@gmail.com
  # yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy UUID for user Y
  #
  ALLOWED_KEYS = open("#{Sinatra::Application.settings.root}/db/app.keys").map { |line| line.split(' ')[0] }

  #
  # json  
  # in developement environment: dump pretty print JSON, 
  # in others environments: dump "minified" JSON
  #
  def json( dataset )
    if !dataset #.empty? 
      return no_data!
    end  

    if settings.development?
      #MultiJson.dump(dataset, :pretty => true) + "\n"
      JSON.pretty_generate(JSON.load(dataset.to_json)) + "\n"  
    else
      MultiJson.dump dataset
    end
  end

  #
  # Authorization parameter in request header ("API KEY"), must be an UUID present in app.keys file 
  #
  def authorized?
    api_key = request.env["HTTP_KEY"] # "HTTP_AUTHORIZATION" 
    #STDERR.puts request.inspect
    
    # return data in case of authorized API_KEY
    (ALLOWED_KEYS.include? api_key) ? true : false 
  end

  def not_authorized!
      status 401
      json :message => "sorry, you are not authorized."
  end

  def no_data!
    status 204
    #json :message => "no data"
  end

end

get "/" do
=begin  
  STDERR.puts
  STDERR.puts "request header:"
  STDERR.puts request.inspect
  STDERR.puts
  STDERR.puts "request body:"
  STDERR.puts request.body.read.inspect
=end
  json :message => "Sinatra API Server Toolbox, by giorgio.robino@gmail.com"
end


#
# CRUD verbs on Note model
#
get "/notes" do
  json Note.all
end

#
# READ
#
get "/notes/:id" do
  json Note.find params[:id]
end

#
# CREATE
#
# usage example:
# curl -i -X POST http://localhost:9393/notes -d '{ "title":"prova", "body":"corpo del messaggio di prova!" }'
#
post "/notes" do

  # get parameters form request body in JSON format  
  new_note = MultiJson.load(request.body.read)

  @note = Note.new( new_note ) #params[:note]
  if @note.save
    json @note
  else
    # return errors if errors present (validations fail), 
    json @note.errors.messages
  end
end

#
# UPDATE
#
# usage example:
# curl -i -X PUT http://localhost:9393/notes/9 -d '{ "title":"prova", "body":"corpo del messaggio di prova!" }'
#
put "/notes/:id" do
  @note = Note.find_by_id params[:id]
 
  if !@note
    no_data!
  else
    new_note = MultiJson.load request.body.read

    if @note.update_attributes(new_note)
      json @note
    else
      json @note.errors.messages
    end
  end
end

#
# DELETE
#
delete "/notes/:id" do
    @note = Note.find_by_id params[:id]
 
  if !@note
    no_data!
  else
    @note.destroy
    no_data!
  end
end


get "/courses" do
  json Course.all
end

# WARN: BAD! in case of a table with a lot of rows!
get "/exams" do
  json Exam.all
end

#
# call example with API KEY (meta info, say parameter in HTTP request header)
# see for fun: https://httpkit.com/resources/HTTP-from-the-Command-Line/
# 
# usage example:
# curl -X GET http://localhost:9393/users -H "key: c39547b2-dfcc-4c24-a867-55f26e1ca772"
#
get "/users" do
  # return data if passed API_KEY is authorized 
  if authorized?
    json User.all
  else
    not_authorized!
  end  
end


#
# retrun all data, with pagination 
# :limit == number of record per page, 
# :offset ==  (numero pagina -1) * (:limit), 
# by example third page with 10 record per page is: 
# Exam.limit(10).offset(2*10)
#
get "/exams/paginate/:limit/:offset" do
  json Exam.limit(params[:limit]).offset(params[:offset])
end

get "/exams/last_twenty" do
  json Exam.select([:id, :cognomenome, :matricola, :updated_at]).order("updated_at DESC").limit(20)
end

# as above, but using plain SQL instead of ActiveRecords ORM DSL...
get "/exams/last_twenty_by_sql" do
  json Exam.find_by_sql('SELECT id, cognomenome, matricola, updated_at FROM exams ORDER BY updated_at DESC LIMIT 20')
 end

get "/exams/last" do
  json Exam.last
end

get "/exams-count" do
  json :message => Exam.count
end


#
# WARN: keep attention of order of insering  /exams/*  in source code 
# this endpoint must stay HERE, AFTER all above...
#
get "/exams/:id" do
  json Exam.find_by_id params[:id]
=begin
  if exam
    json exam
  else
    no_data!
  end  
=end
end


#
# client side POST example, 
# where parameters are passed in request body: 
# curl -X POST http://localhost:9393/login -d '{ "username":"admin", "password":"admin" }'
# curl -X POST http://localhost:9393/login -d '{ "username":"user", "password":"admin" }' -H 'Content-Type: application/json'
#
post "/login" do
  # params_json = MultiMultiJson.load(request.body.read) # jdata = params[:data]
  login = MultiJson.load request.body.read 

  if (login["username"] == "admin") and (login["password"] == "admin")
    json :message => "OK: login passed"
  else
    json :message => "ERROR: invalid username or password"
  end 

  # echo: return same parameters of POST...
  #json @login 
end


#
# File Upload
# see also:
# http://www.convalesco.org/blog/2013/01/10/direct-file-upload-with-sinatra/
# https://gist.github.com/runemadsen/3905593
#
# use curl to upload files to your app, by example with commanf line:
# curl --upload-file file.txt http://localhost:9393/upload/
#
put '/upload/:filename' do
  File.open("./public/#{params[:filename].to_s}", 'w+') do |file|
    file.write(request.body.read)
  end
end

#
# File Download
# command line example:
# curl http://localhost/download/file.txt
#
get '/download/:filename' do
  file = File.join(settings.public_folder, "#{params[:filename].to_s}")
  if File.exists?(file)
    attachment 
    send_file file #, :disposition => :attachment
  else
    json :message => "ERROR: file not found"
  end  
end

not_found do
  json :message => 'This is nowhere to be found.'
end

error do
  json :message => 'Sorry there was a nasty error - ' + env['sinatra.error'].name
end
