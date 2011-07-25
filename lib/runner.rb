require 'bundler/setup'
require 'yaml'
require 'json'
require 'ostruct'
require 'runner_utils'
require 'generator'
require 'nagios_controller'

##
# Main runner class that should be the entry to the app. Resque delegate.
#
# @author Josh Lindsey
# @since 0.0.1
class Runner
  # Default queue for Resque
	@queue = :nagios

  class << self
    ##
    # Main entry point for Resque.
    #
    # @param [String] action The action to perform. Should be either "register" or "unregister".
    # @param [Hash] data The node and runlist data posted by Chef.
    def perform action, data
      # Initial setup
      controller = NagiosController.new

      RunnerUtils.debug "Init for new run. Action: #{action.inspect}\nData: #{data.inspect}"

      # Take the appropriate action
      case action
			when 'register'
				parsed_tags = parse_tags data['node']['tags']

				gen = Generator.new node_name: data['node']['node_name'],
														local_ipv4: data['node']['local_ipv4'],
														contact: parsed_tags['client'],
														hostgroup_override: parsed_tags['hostgroup'],
														run_list: data['run_list'].map(&:downcase)

				hostgroup_configs = gen.generate_hostgroups
        config = gen.generate
        create_files! data['node']['node_name'], config
				create_hostgroups! hostgroup_configs
        controller.restart

        RunnerUtils.info "Registered node: #{data['node']['node_name']}"
      when 'unregister'
        remove_files! data['node_name']
        controller.restart

        RunnerUtils.info "Unregistered node: #{data['node_name']}"
      else
        RunnerUtils.fatal "Unknown or missing action: #{action}"
        raise "Unknown or missing action: #{action}"
      end
    end

		##
		#	Parses the node's tags into a Hash. Essentially just splits on ":".
		#	Ignores tags that don't follow this convention.
		#
		#	@param [Array<String>] tags The array of node tags
		#	@return [Hash] The parsed tags in a Hash
		def parse_tags tags
			RunnerUtils.debug "Parsing tags: #{tags}"

			parsed = {}
			tags.each do |tag|
				if /^(?<key>.*?):(?<value>.*?)$/ =~ tag
					parsed[key] = value
				else
					RunnerUtils.debug "Ignoring tag: #{tag}"
				end
			end

			unless parsed.keys.include? "client"
				RunnerUtils.warn "No client tag found, defaulting to #{RunnerUtils.app_config.default_client}"
				parsed["client"] = RunnerUtils.app_config.default_client
			end

			unless parsed.keys.include? "hostgroup"
				RunnerUtils.debug "No hostgroup override found, defaulting to :default"
				parsed["hostgroup"] = :default
			end

			RunnerUtils.debug "Parsed tags: #{parsed}"
			parsed
		end

    ##
    # Creates the file structure for generated configs, and writes out the config data to them.
    #
		# @see {Generator#generate}
    # @param [String] node_name The node_name to be used for naming the file.
    # @param [String] config_data The configuration data to write out to the files.
    def create_files! node_name, config_data
      unless RunnerUtils.app_config.output_dir.exist?
        RunnerUtils.info "Created output directory at #{RunnerUtils.app_config.output_dir.to_s}"
        RunnerUtils.app_config.output_dir.mkpath
      end

      filename = RunnerUtils.app_config.output_dir + "#{node_name}.cfg"

      if filename.exist?
        RunnerUtils.warn "Config file already exists: #{filename.to_s}"

        unless RunnerUtils.app_config.allow_overwrites == true
          RunnerUtils.fatal "Refusing to overwrite existing config at #{filename.to_s}"
          raise "Not configured to overwrite. Offending file at #{filename.to_s}"
        end
      end

      filename.open('w') { |f| f.puts config_data }

      RunnerUtils.debug "Wrote config to file #{filename.to_s}"
    end

		##
		# Creates the file structure for generated hostgroups, and writes out the config data.
		#
		# @see {Generator#generate_hostgroups}
		# @param [Hash] configs The has containing the hostgroup name and its config string
		def create_hostgroups! configs
			RunnerUtils.debug "Writing hostgroup configs"

			configs.each_pair do |group, config|
				path = RunnerUtils.app_config.output_dir + File.join("hostgroups", "#{group}.cfg")
				unless path.dirname.exist?
					RunnerUtils.info "Created hostgroup directory at #{File.dirname(path)}"
					FileUtils.mkdir_p File.dirname(path) unless File.directory? path
				end

				path.open('w') { |f| f.puts config }

				RunnerUtils.debug "Wrote hostgroup config to file #{path.to_s}"
			end
		end

    ##
    # Removes the configuration files for a node on deregistration.
    #
    # @param [String] node_name The node_name to be used for finding the file to be removed.
    def remove_files! node_name
      filename = RunnerUtils.app_config.output_dir + "#{node_name}.cfg"
      
			# TODO: Make this a warning and don't halt execution
      unless filename.exist?
        RunnerUtils.fatal "Unregister for #{node_name} expects nonexistant file to exist at #{filename.to_s}"
        raise "Can't delete nonexistant file at #{filename.to_s}"
      end

      filename.delete
      RunnerUtils.debug "Deleted file at #{filename.to_s}"
    end
  end
end

