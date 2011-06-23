require 'rubygems'
require 'bundler/setup'
require 'yaml'
require 'json'
require 'ostruct'
require 'logger'
require 'generator'
require 'nagios_controller'

##
# Main runner class that should be the entry to the app. Resque delegate.
#
# @author Josh Lindsey
# @since 0.0.1
class Runner
	@queue = :nagios

  ConfigFile = File.expand_path(File.join('..', 'config', 'app_config.yaml'), File.dirname(__FILE__))

  class << self
    ##
    # Main entry point for Resque.
    #
    # @param [String] action The action to perform. Should be either "register" or "unregister".
    # @param [Hash] data The node and runlist data posted by Chef.
    def perform action, data
      # Initial setup
      $app_conf = load_$app_config
      $logger = Logger.new $app_conf.log_file
      $logger.level = $app_conf.log_level

      controller = NagiosController.new

      $logger.debug "Init for new run. Action: #{action.inspect}\nData: #{data.inspect}"

      # Take the appropriate action
      case action
      when 'register'
        config = generate_config data
        create_files! data['node']['node_name'], config
        controller.restart

        $logger.info "Registration complete for #{data['node']['node_name']}"
      when 'unregister'
        remove_files! data['node_name']
        controller.restart

        $logger.info "Unregistration complete for #{data['node_name']}"
      else
        $logger.fatal "Unknown or missing action: #{action}"
        raise "Unknown or missing action: #{action}"
      end
    end

    ##
    # Loads the app config file into an [OpenStruct] and returns it.
    #
    # @return [OpenStruct] The app config
    def load_app_cofig
      app_config = YAML.load_file ConfigFile

      app_config['log_file'] &&= Pathname.new app_config['log_file']
      app_config['output_dir'] &&= Pathname.new app_config['output_dir']
      app_config['log_level'] &&= Logger.const_get(app_config['log_level'])

      OpenStruct.new app_config
    end

    ##
    # Uses [Generator] to generate all the Nagios config declarations required by this Host
    #
    # @return [String] The generated configs
    def generate_config data
      gen_opts = {
        :node_name => data['node']['node_name'],
        :local_ipv4 => data['node']['local_ipv4'],
        :run_list => data['run_list']
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
      unless $app_conf.output_dir.exist?
        $logger.warn "Created output directory at #{$app_conf.output_dir.to_s}"
        $app_conf.output_dir.mkpath
      end

      filename = $app_conf.output_dir + "#{node_name}.cfg"

      if filename.exist?
        $logger.warn "Config file already exists: #{filename.to_s}"

        unless $app_conf.allow_overwrites == true
          $logger.fatal "Refusing to overwrite existing config at #{filename.to_s}"
          raise "Not configured to overwrite. Offending file at #{filename.to_s}"
        end
      end

      filename.open('w') { |f| f.puts config_data }

      $logger.info "Wrote config to file #{filename.to_s}"
    end

    ##
    # Removes the configuration files for a node on deregistration.
    #
    # @param [String] node_name The node_name to be used for finding the file to be removed.
    def remove_files! node_name
      filename = $app_conf.output_dir + "#{node_name}.cfg"
      
      unless filename.exist?
        $logger.fatal "Unregister for #{node_name} expects nonexistant file to exist at #{filename.to_s}"
        raise "Can't delete nonexistant file at #{filename.to_s}"
      end

      filename.delete
      $logger.info "Deleted file at #{filename.to_s}"
    end
  end
end

