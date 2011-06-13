require 'rubygems'
require 'erubis/tiny'
require 'yaml'
require 'ostruct'
require 'set'

##
# Accepts data from the message runner and generates the Nagios configs based on the ERB templates.
#
# @author Josh Lindsey
# @since 0.0.1
class Generator
  @@mappings_file = File.expand_path(File.dirname(__FILE__) + '/../../config/mappings.yaml')

  attr_reader :mappings, :services, :context

  ##
  # New Generator instance.
  #
  # @param [Hash] opts The initialization options
  # @option opts [String] :node_name The Chef node name
  # @option opts [Array<String>] :node_groups The groups to which this node belongs
  # @option opts [String] :local_ipv4 The Local IP address of the node
  # @option opts [Array<String>] :run_list The run list applied to the node
  def initialize opts = {}
    [:node_name, :node_groups, :local_ipv4, :run_list].each do |req|
      raise "Missing required init option: #{req}" unless opts.keys.include? req
    end

    @mappings = YAML.load_file @@mappings_file
    @context = OpenStruct.new opts
    @services = Set.new
  end

  ##
  # Entry point into the object, generates a Nagios config string based on the initialization options,
  # to be written to a file later by the Runner.
  #
  # @return [String] The generated config
  def generate
    get_services!

    o = ''
    host = Erubis::TinyEruby.new(File.read(File.expand_path(File.dirname(__FILE__) + '/templates/host.erb')))
    service = Erubis::TinyEruby.new(File.read(File.expand_path(File.dirname(__FILE__) + '/templates/service.erb')))

    o << host.evaluate(self.context) << "\n"

    self.services.each do |s|
      context_hash = self.context.marshal_dump

      struct = OpenStruct.new
      struct.node_name = self.context.node_name
      struct.service_name = (s.first =~ /%{.*}/) ? (s.first % context_hash) : s.first
      struct.service_command = (s.last =~ /%{.*}/) ? (s.last % context_hash) : s.last

      o << service.evaluate(struct) << "\n"
    end

    o.strip
  end

  ##
  # Parses the run_list from the init opts and compiles a list of servies to generate configs for, 
  # based on the mappings loaded from the config.
  #
  # @TODO figure out what to do when it can't find a mapping for a run_list item
  def get_services!
    self.context.run_list.each do |item|
      # Parse item
      unless /(?<type>\w+)\[(?<name>\w+)\]/ =~ item
        next
      end
     
      # Add all basic checks
      self.mappings['basic_checks'].each { |check| @services << check }

      # Get the checks for this item
      self.mappings[type][name].each { |check| @services << check }
    end
  end
end
