require 'rubygems'
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
        config = generate_config data
        create_files! data['node']['node_name'], config
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
    # Uses [Generator] to generate all the Nagios config declarations required by this Host
    #
    # @return [String] The generated configs
    def generate_config data
      gen_opts = {
        node_name: data['node']['node_name'],
        local_ipv4: data['node']['local_ipv4'],
        run_list: data['run_list']
      }

      gen = Generator.new gen_opts
      gen.generate
    end

    ##
    # Creates the file structure for generated configs, and writes out the config data to them.
    #
    # @param [String] node_name The node_name to be used for naming the file.
    # @param [String] config_data The configuration data to write out to the files.
    def create_files! node_name, config_data
      unless RunnerUtils.app_config.output_dir.exist?
        RunnerUtils.warn "Created output directory at #{RunnerUtils.app_config.output_dir.to_s}"
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
    # Removes the configuration files for a node on deregistration.
    #
    # @param [String] node_name The node_name to be used for finding the file to be removed.
    def remove_files! node_name
      filename = RunnerUtils.app_config.output_dir + "#{node_name}.cfg"
      
      unless filename.exist?
        RunnerUtils.fatal "Unregister for #{node_name} expects nonexistant file to exist at #{filename.to_s}"
        raise "Can't delete nonexistant file at #{filename.to_s}"
      end

      filename.delete
      RunnerUtils.debug "Deleted file at #{filename.to_s}"
    end
  end
end

