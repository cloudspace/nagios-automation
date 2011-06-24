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
  MappingsFile = File.expand_path(File.join(File.dirname(__FILE__),  '..', 'config', 'mappings.yaml'))
  TemplatesDir = File.expand_path(File.join(File.dirname(__FILE__), 'templates'))

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
    [:node_name, :local_ipv4, :run_list].each do |req|
      unless opts.keys.include? req
        RunnerUtils.fatal "Missing required Generator option: #{req}"
        raise "Missing required init option: #{req}"
      end
    end

    @mappings = YAML.load_file MappingsFile
    RunnerUtils.debug "Loaded mappings: #{@mappings.inspect}"

    @context = get_context opts
    RunnerUtils.debug "Created context: #{@context.insepct}"

    @services = Set.new
  end

  ##
  # Entry point into the object, generates a Nagios config string based on the initialization options,
  # to be written to a file later by the Runner.
  #
  # @return [String] The generated config
  def generate
    RunnerUtils.debug "Generating config"

    get_services!

    o = ''
    host = Erubis::TinyEruby.new(File.read(File.join(TemplatesDir, 'host.erb')))
    service = Erubis::TinyEruby.new(File.read(File.join(TemplatesDir, 'service.erb')))

    o << host.evaluate(self.context) << "\n"

    self.services.each do |s|
      RunnerUtils.debug "Generating config for service #{s.inspect}"

      context_hash = self.context.marshal_dump

      struct = OpenStruct.new
      struct.node_name = self.context.node_name
      struct.service_name = (s.first =~ /%\{.*\}/) ? (s.first % context_hash) : s.first
      struct.service_command = (s.last =~ /%\{.*\}/) ? (s.last % context_hash) : s.last

      o << service.evaluate(struct) << "\n"
    end

    RunnerUtils.debug "Config generated: #{o}"
    o.strip
  end

  ##
  # Parses the opts from [#initialize] into an [OpenStruct] to be used in [#generate].
  # 
  # @return [OpenStruct] The parsed opts in OpenStruct form.
  def get_context opts
    os = OpenStruct.new opts
    groups = []

    os.run_list.each do |item|
      if /role\[(?<group>.+?)\]/ =~ item
        groups << group
      end
    end

    if groups.empty?
      RunnerUtils.warn "No roles detected, adding node #{opts.node_name} to ungrouped"
      groups << "ungrouped"
    end

    os.node_groups = groups

    os
  end

  ##
  # Parses the run_list from the init opts and compiles a list of servies to generate configs for, 
  # based on the mappings loaded from the config.
  #
  # @TODO figure out what to do when it can't find a mapping for a run_list item
  def get_services!
    # Add all basic checks
    self.mappings['basic_checks'].each { |check| @services << check }

    self.context.run_list.each do |item|
      RunnerUtils.debug "Parsing runlist item: #{item}"

      # Parse item
      unless /(?<type>.+?)\[(?<name>.+?)\]/ =~ item
        RunnerUtils.warn "Unable to parse runlist item: #{item}"
        next
      end

      # Get the checks for this item
      begin
        if self.mappings['ignored'][type].include? name
          RunnerUtils.debug "Ignoring #{item}"
          next
        end

        checks = self.mappings[type][name]
        raise NoMethodError if checks.nil? or checks.empty?

        checks.each { |check| @services << check }
      rescue NoMethodError => e
        RunnerUtils.warn "Unknown service or no checks defined for #{item}"
      end
    end
  end
end
