require File.join(File.dirname(__FILE__), 'application')
require 'rubygems'
require 'bundler/setup'
require 'erubis'
require 'resque/server'

set :run, false
set :environment, :production

FileUtils.mkdir_p 'log' unless File.exists?('log')
log = File.new("log/sinatra.log", "a+")
$stdout.reopen(log)
$stderr.reopen(log)

Resque::Server.use Rack::Auth::Basic do |user, pass|
	user == "cloudspace" and password == "iloveresque"
end

run Rack::URLMap.new \
  "/"       => Sinatra::Application.new,
  "/resque" => Resque::Server.new

