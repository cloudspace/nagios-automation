require 'bundler/setup'
require 'sinatra'
require 'json'
require 'resque'

configure do
  $:.unshift File.expand_path('lib', File.dirname(__FILE__))
  Dir['lib/*.rb'].each { |lib| require File.basename(lib) }
end

before do
  content_type :json
  headers 'Connection' => 'close'
end

get '/' do
  status 404
end

post '/register' do
  out = { :success => true }.to_json
  code = 200

  begin
    parsed = JSON(request.body.read)
    Resque.enqueue(Runner, 'register', parsed)
  rescue Exception => e
    out = { :success => false, :error => e.to_s }.to_json
    code = 500
  end

  status code
  body out
end

post '/unregister' do
  out = { :success => true }.to_json
  code = 200

  begin
    parsed = JSON(request.body.read)
    Resque.enqueue(Runner, 'unregister', parsed)
  rescue Exception => e
    out = { :success => false, :error => e.to_s }.to_json
    code = 500
  end
  
  status code
  body out
end

