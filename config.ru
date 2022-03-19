# config.ru
require './server' 
require 'thin' 
run Sinatra::Application
