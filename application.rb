require 'rubygems'
require 'bundler/setup'
require 'sinatra'
require 'json'
require 'resque'

$:.unshift File.expand_path('lib', File.dirname(__FILE__))
Dir['lib/*.rb'].each { |lib| require File.basename(lib) }

post '/register' do
  content_type 'application/json'

  begin
    parsed = JSON(request.body.read)
    Resque.enqueue(Runner, 'register', parsed)
   
    out = { :success => true }.to_json

    status 200
    body out
  rescue Exception => e
    out = { :success => false, :error => e.to_s }.to_json

    status 500
    body out
  end
end

post '/unregister' do
  content_type 'application/json'
  
  begin
    parsed = JSON(request.body.read)
    Resque.enqueue(Runner, 'unregister', parsed)
    
    out = { :success => true }.to_json

    status 200
    body out
  rescue Exception => e
    out = { :success => false, :error => e.to_s }.to_json

    status 500
    body out
  end
end

