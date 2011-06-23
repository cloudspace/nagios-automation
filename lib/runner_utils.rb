require 'mail'
require 'ostruct'
require 'logger'
require 'yaml'

##
# A utility module for accessing app settings, methods, and singletons such as the logger object.
module RunnerUtils

  ConfigFile = File.expand_path(File.join('..', 'config', 'app_config.yaml'), File.dirname(__FILE__))

  class << self

    ##
    # Singleton access method for the internal loaded app config.
    #
    # @see {.load_app_config}
    # @return [OpenStruct] The singleton app config.
    def app_config
      @@app_config ||= load_app_config
    end

    ##
    # Allows for calling {Logger} convenience methods {#debug}, #{error}, etc.
    #
    # @param [Symbol] sym The method symbol to pass in.
    # @param [*Array] args The splatted array of args to pass
    def method_missing sym, *args
      if [:debug, :info, :warn, :error, :fatal].include? sym
        log sym, *args
      else
        super
      end
    end

    ##
    # Corresponds to {#method_missing} to allow for class reflection.
    #
    # @param [Symbol] sym The message symbol
    def respond_to? sym
      if [:debug, :info, :warn, :error, :fatal].include? sym
        true
      else
        super
      end
    end

    ##
    # Abstraction over {Logger#log}, allowing us to more easily send emails in a centralized location.
    # This method will log the specified message and level, then optionally send an email if the app
    # is configured appropriately.
    #
    # @param [Symbol] level The level to log this message at. See {Logger} for severity levels.
    # @param [String] message The message to log
    def log level, message
      const_level = Logger.const_get(level.to_s.upcase)
      logger.log const_level, message

      # Using the {Logger} consts for simplicity here
      email_threshold = Logger.const_get(app_config.email_alert_level.upcase)
      if email_threshold <= const_level
        app_config.emails.each do |addr|
          Mail.deliver do
            to      addr
            from    'Nagios Automator <admin@cloudspace.com>'
            subject "[#{level.to_s.upcase}] #{message.split(/\.\s+/).first}"
            body    message
          end
        end
      end
    end

    private

    ##
    # Loads the app config file into an [OpenStruct] and returns it.
    #
    # @return [OpenStruct] The app config
    def load_app_cofig
      app_config = YAML.load_file ConfigFile

      app_config['log_file'] &&= Pathname.new app_config['log_file']
      app_config['output_dir'] &&= Pathname.new app_config['output_dir']
      app_config['log_level'] &&= Logger.const_get(app_config['log_level'].upcase)

      OpenStruct.new app_config
    end

    ##
    # Singleton method for the internal {Logger} object.
    #
    # @return [Logger] The internal Logger
    def logger
      if @@logger.nil?
        @@logger = Logger.new app_config.log_file
        @@logger.level = app_config.log_level
      end

      @@logger
    end
  end
end

