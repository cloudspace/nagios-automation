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
    parsed = JSON(params[:message])
    Resque.enqueue(Runner, 'register', parsed)

    { :success => true }.to_json
  rescue Exception => e
    { :success => false, :error => e.to_s }.to_json
  end
end

post '/unregister' do
  content_type 'application/json'
  
  begin
    parsed = JSON(params[:message])
    Resque.enqueue(Runner, 'unregister', parsed)
    
    { :success => true }.to_json
  rescue Exception => e
    { :success => false, :error => e.to_s }.to_json
  end
end

