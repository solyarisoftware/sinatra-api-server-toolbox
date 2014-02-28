require 'rack'
require './app'

# https://coderwall.com/p/4kn4zw
use Rack::Deflater
run Sinatra::Application

