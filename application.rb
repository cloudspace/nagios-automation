require 'rubygems'
require 'bundler/setup'
require 'sinatra'
require 'json'

post '/register' do
  content_type 'application/json'
end

post '/unregister' do
  content_type 'application/json'
end

