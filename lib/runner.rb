require 'rubygems'
require 'bundler/setup'
require 'json'
require 'fileutils'
require 'generator'
require 'nagios_controller'

##
# Main runner class that should be the entry to the app. Resque delegate.
#
# @author Josh Lindsey
# @since 0.0.1
class Runner
	@queue = :nagios

  DefaultOutputDir = '/etc/nagios3/conf.d/auto'

  class << self
    ##
    # Main entry point for Resque.
    #
    # @param [String] action The action to perform. Should be either "register" or "unregister".
    # @param [Hash] data The node and runlist data posted by Chef.
    def perform action, data
      controller = NagiosController.new

      case action
      when 'register'
        config = generate_config data
        create_files! data['node']['node_name'], config
        controller.restart
      when 'unregister'
        remove_files! data['node_name']
        controller.restart
      else
        raise "Unknown or missing action: #{action}"
      end
    end

    ##
    # Uses [Generator] to generate all the Nagios config declarations required by this Host
    #
    # @return [String] The generated configs
    def generate_config data
      gen_opts = {
        :node_name => data['node']['node_name'],
        :local_ipv4 => data['node']['local_ipv4'],
        :run_list => data.run_list
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
      FileUtils.mkdir_p DefaultOutputDir
      File.open(File.join(DefaultOutputDir, node_name + '.cfg'), 'w') do |f|
        f.puts config_data
      end
    end

    ##
    # Removes the configuration files for a node on deregistration.
    #
    # @param [String] node_name The node_name to be used for finding the file to be removed.
    def remove_files! node_name
      FileUtils.rm_f File.join(DefaultOutputDir, node_name + '.cfg')
    end
  end
end

