require 'rubygems'
require 'bundler/setup'
require 'resque/tasks'

desc "Load the app environment into rake for Resque tasks."
task :environment do
  $:.unshift File.expand_path('lib', File.dirname(__FILE__))
  Dir['lib/*.rb'].each { |lib| require File.basename(lib) }
end

