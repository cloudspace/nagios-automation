require 'ohai'

##
# Abstraction over just calling `service nagios3 restart` to allow flexibility in deployment.
#
# @author Josh Lindsey
# @since 0.0.1
class NagiosController
  include Open3

  attr_accessor :platform
  attr_accessor :platform_version

  @@platform_commands = {
    "ubuntu" => {
      :start => 'service nagios3 start',
      :stop => 'service nagios3 stop',
      :restart => 'service nagios3 restart' 
    }
  }

  ##
  # Initializes a new {NagiosController} object. Detects platform and stores it for later.
  def initialize
    detect_platform!
  end
 
  ##
  # Alows me to DRY up the code a bit by just passing the command along to {#run} since they're
  # all basically the same logic with different command strings.
  #
  # @param [Symbol] sym The message symbol
  # @param [*Array] args The splatted array of arguments
  def method_missing sym, *args
    if [:start, :stop, :restart].include? sym
      self.run sym
    else
     super
    end
  end

  ##
  # Corresponds to the {#method_missing} calls to allow for proper reflection of the class.
  #
  # @param [Symbol] sym The message symbol
  def respond_to? sym
    if [:start, :stop, :restart].include? sym
      true
    else
      super
    end
  end

  ##
  # Runs the actual Nagios service control commands.
  #
  # @param [Symbol] cmd The service command to run.
  def run cmd
    begin
      command = @@platform_commands[@platform][cmd]
      raise NoMethodError if command.nil?
    rescue NoMethodError => e
      return
    end

		system command
  end

  ##
  # Detects the current platform by way of Ohai.
  def detect_platform!
    o = Ohai::System.new
    %w(os platform).each { |plugin| o.load_plugin plugin }
    @platform = o.platform
    @platform_version = o.platform_version
  end
end
