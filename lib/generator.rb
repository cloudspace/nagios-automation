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
	# @option opts [Sting] :contact The contact group for services
  # @option opts [Array<String>] :run_list The run list applied to the node
  def initialize opts = {}
    [:node_name, :local_ipv4, :contact, :hostgroup_override, :run_list].each do |req|
      unless opts.keys.include? req
        RunnerUtils.fatal "Missing required Generator option: #{req}"
        raise "Missing required init option: #{req}"
      end
    end

    @mappings = YAML.load_file MappingsFile
    RunnerUtils.debug "Loaded mappings: #{@mappings.inspect}"

    @context = get_context opts
    RunnerUtils.debug "Created context: #{@context.inspect}"

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
			struct.contact = self.context.contact
      struct.service_name = (s.first =~ /%\{.*\}/) ? (s.first % context_hash) : s.first
      struct.service_command = (s.last =~ /%\{.*\}/) ? (s.last % context_hash) : s.last

      o << service.evaluate(struct) << "\n"
    end

    RunnerUtils.debug "Config generated: #{o}"
    o.strip
  end

	##
	#	Alternate entry point. Generates an array of hostgroup configs to ensure consistency on deploys.
	#	The files are later written out by the Runner.
	#
	#	@return [Hash] The hash of hostgroup name to config string mappings
	def generate_hostgroups
		RunnerUtils.debug "Generating hostgroup configs for #{self.context.node_groups}"

		configs = {}
		template = Erubis::TinyEruby.new(File.read(File.join(TemplatesDir, 'hostgroup.erb')))

		self.context.node_groups.each do |group|
			struct = OpenStruct.new :hostgroup => group
			configs[group] = template.evaluate(struct)
		end

		RunnerUtils.debug "Hostgroup configs generated: #{configs}"
		configs
	end

  ##
  # Parses the opts from [#initialize] into an [OpenStruct] to be used in [#generate].
  # 
  # @return [OpenStruct] The parsed opts in OpenStruct form.
  def get_context opts
    os = OpenStruct.new opts
    groups = []

		if opts[:hostgroup_override] == :default
			os.run_list.each do |item|
				if /role\[(?<group>.+?)\]/ =~ item
					groups << group
				end
			end
		else
			groups << opts[:hostgroup_override]
		end

    if groups.empty?
      RunnerUtils.warn "No roles detected, adding node #{opts.node_name} to #{RunnerUtils.app_config.default_hostgroup}"
      groups << RunnerUtils.app_config.default_hostgroup
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

      # Recipes with ::default are redundant, so we remove it to 
      # make the mappings file simpler.
      name.sub! /::default$/, '' if type == 'recipe'

      # Get the checks for this item
      begin
        if self.mappings['ignored'][type].include? name
          RunnerUtils.debug "Ignoring #{item}"
          next
        end

        # TODO: This flatten / each_slice logic seems hackish, but I can't think of a better way to
        #       make the YAML recipe-to-role anchoring work.
        checks = self.mappings[type][name].flatten
        raise NoMethodError if checks.nil? or checks.empty?

        checks.each_slice(2) { |check| @services << check }
      rescue NoMethodError => e
        RunnerUtils.warn "Unknown service or no checks defined for #{item}"
      end
    end
  end
end
