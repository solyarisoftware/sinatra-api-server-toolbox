require 'json'
require 'sinatra'
require 'sinatra/activerecord'

# connessione a database postgresql già esistente
# http://amaras-tech.co.uk/article/111/Sinatra_ActiveRecord_DB_config_on_Heroku
ActiveRecord::Base.establish_connection(ENV['ESAMIANATOMIA_DB_URL'] || 'postgres://YOURUSERNAME:YOURPASSWORD@HOSTIPADDRESS/esamiAnatomia_development')

# dichiarazione delle tabelle a cui accedere 

class Exam < ActiveRecord::Base
end

class User < ActiveRecord::Base
end

class Course < ActiveRecord::Base
end

# caso specifico di Modello (tabella) appartenente a database differente da quello di default!
class Note < ActiveRecord::Base
  # connessione a specifico db  
  establish_connection(ENV['SAR_DB_URL'] || 'postgres://YOURUSERNAME:YOURPASSWORD@HOSTIPADDRESS/sar')

  # set del nome di una tabella, nel caso in cui non sia fatta con convenzione Rails 
  self.table_name = "notes"

  # validazioni activerecord 
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

=begin
set :environment, :production

# http://stackoverflow.com/questions/8772641/how-to-define-global-error-handler-for-json-in-sinatra
error do
  content_type :json
  status 400 # or whatever

  e = env['sinatra.error']
  {:result => 'error', :message => e.message}.to_json
end
=end

helpers do

  # elenco api-keys permesse: 
  # le chiavi sono lette dal file di testo in chiaro... /db/app.keys (just a demo!)
  # dove ogni linea ha formato {key}blank{comments}, per esempio: 
  # xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx UUID for user X, X@gmail.com
  # yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy UUID for user Y
  #
  ALLOWED_KEYS = open("#{Sinatra::Application.settings.root}/db/app.keys").map { |line| line.split(' ')[0] }


  # in ambiente di sviluppo: pretty print JSON, altrimenti: JSON minimale
  def to_json( dataset )
    if !dataset #.empty? 
      return no_data!
    end  

    if settings.development?
      JSON.pretty_generate(JSON.parse(dataset.to_json)) + "\n"  
    else
      dataset.to_json
    end
  end

  # il parametro "Authorization" in request header (API KEY), deve essere uno UUID censito 
  def authorized?
    api_key = request.env["HTTP_KEY"] # "HTTP_AUTHORIZATION" 
    #STDERR.puts request.inspect
    
    # ritorna dati se la chiamata ha una chiave autorizzata
    (ALLOWED_KEYS.include? api_key) ? true : false 
  end

  def not_authorized!
      status 401
      to_json ( { :message => "sorry, you are not authorized." } )    
  end

  def no_data!
    status 204
    #to_json ({ :message => "no data" })
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
  to_json ( { :message => "JSON API DEMO (ruby, sinatra, activerecord, postgresql) by: giorgio.robino@gmail.com"} )
end


# operazioni CRUD sul modello Note
get "/notes" do
  to_json Note.all
end

# READ
get "/notes/:id" do
  to_json Note.find(params[:id])
end

# CREATE
# curl -i -X POST http://localhost:9393/notes -d '{ "title":"prova", "body":"corpo del messaggio di prova!" }'
post "/notes" do

  new_note = JSON.parse(request.body.read)

  # paranetri presi dal request body
  @note = Note.new( new_note ) #params[:note]
  if @note.save
    to_json @note
  else
    # se ci sono errori (validazioni non superate), ritorna errori
    to_json @note.errors.messages
  end
end

# UPDATE
# curl -i -X PUT http://localhost:9393/notes/9 -d '{ "title":"prova", "body":"corpo del messaggio di prova!" }'
put "/notes/:id" do
  @note = Note.find_by_id(params[:id])
 
  if !@note
    no_data!
  else
    new_note = JSON.parse(request.body.read)

    if @note.update_attributes(new_note)
      to_json @note
    else
      to_json @note.errors.messages
    end
  end
end

# DELETE
delete "/notes/:id" do
    @note = Note.find_by_id(params[:id])
 
  if !@note
    no_data!
  else
    @note.destroy
    no_data!
  end
end

######################

get "/courses" do
  to_json Course.all
end

# occhio: no è bello con tabella di 10000 righe!
get "/exams" do
  to_json Exam.all
end

# gestisce API KEY (meta informazione, ovvero parametro,  nell'HTTP request header)
# https://httpkit.com/resources/HTTP-from-the-Command-Line/
# 
# curl -X GET http://localhost:9393/users -H "key: c39547b2-dfcc-4c24-a867-55f26e1ca772"
get "/users" do
  # ritorna dati se la chiamata ha una chiave autorizzata
  if authorized?
    to_json User.all
  else
    not_authorized!
  end  
end


# ritorna tutto, con paginazione 
# :limit == numero record per pagina, 
# :offset ==  (numero pagina -1) * (:limit), 
# per esempio la terza pagina con 10 record per pagina è: 
# Exam.limit(10).offset(2*10)
get "/exams/paginate/:limit/:offset" do
  to_json Exam.limit(params[:limit]).offset(params[:offset])
end

get "/exams/last_twenty" do
  to_json Exam.select([:id, :cognomenome, :matricola, :updated_at]).order("updated_at DESC").limit(20)
end

# stessa query sopra, ma immettendo SQL invece che metodi di activerecords...
get "/exams/last_twenty_by_sql" do
  to_json Exam.find_by_sql('SELECT id, cognomenome, matricola, updated_at FROM exams ORDER BY updated_at DESC LIMIT 20')
 end

get "/exams/last" do
  to_json Exam.last
end

get "/exams-count" do
  to_json ({ :message => Exam.count })
end


# attenzione all'ordine /exams/... questo metodo va messo nel sorgente, DOPO quelli sopra
get "/exams/:id" do
  to_json Exam.find_by_id(params[:id])
=begin
  if exam
    to_json exam
  else
    no_data!
  end  
=end
end


# esempio di post client side, dove i parametri sono passati nel request body: 
# curl -X POST http://localhost:9393/login -d '{ "username":"admin", "password":"admin" }'
# curl -X POST http://localhost:9393/login -d '{ "username":"user", "password":"admin" }' -H 'Content-Type: application/json'

post "/login" do
  # params_json = JSON.parse(request.body.read) # jdata = params[:data]
  login = JSON.parse(request.body.read)

  if (login["username"] == "admin") and (login["password"] == "admin")
    to_json ( { :message => "OK: login passed" } )
  else
    to_json ( { :message => "ERROR: invalid username or password" } )
  end 

  # echo: ritorna stessi parametri della POST...
  #json @login 
end


# File Upload
# http://www.convalesco.org/blog/2013/01/10/direct-file-upload-with-sinatra/
# https://gist.github.com/runemadsen/3905593
# use curl to upload files to your app
# curl --upload-file file.txt http://localhost:9393/upload/
put '/upload/:filename' do
  File.open("./public/#{params[:filename].to_s}", 'w+') do |file|
    file.write(request.body.read)
  end
end

# File Download
# curl http://localhost/download/file.txt
get '/download/:filename' do
  file = File.join(settings.public_folder, "#{params[:filename].to_s}")
  if File.exists?(file)
    attachment 
    send_file file #, :disposition => :attachment
  else
    to_json ( { :message => "ERROR: file not found" } )
  end  
end

not_found do
  to_json ( { :message => 'This is nowhere to be found.' } )
end

error do
  to_json ( { :message => 'Sorry there was a nasty error - ' + env['sinatra.error'].name } )
end
