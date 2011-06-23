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

  Commands = [:start, :stop, :restart]

  @@platform_commands = {
    "ubuntu" => {
      start:    'service nagios3 start',
      stop:     'service nagios3 stop',
      restart:  'service nagios3 restart' 
    }
  }

  ##
  # Initializes a new {NagiosController} object. Detects platform and stores it for later.
  def initialize
    detect_platform!
    RunnerUtils.debug "Initialized NagiosController. Platform detected as #{self.platform} #{self.platform_version}"
  end
 
  ##
  # Alows me to DRY up the code a bit by just passing the command along to {#run} since they're
  # all basically the same logic with different command strings.
  #
  # @param [Symbol] sym The message symbol
  # @param [*Array] args The splatted array of arguments
  def method_missing sym, *args
    if Commands.include? sym
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
    if Commands.include? sym
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
    command = @@platform_commands[@platform][cmd]
    RunnerUtils.debug "NagiosController running command #{cmd}, translated to #{command}"

    popen2e command do |stdin, out, wait_thread|
      status = wait_thread.value

      if status.to_i != 0
        o = ''; out.each { |line| o << line }
        RunnerUtils.fatal "Nagios command unsuccessful: #{command}. Output:"
        RunnerUtils.fatal o

        raise "Nagios command unsuccessful #{command}. See log for details."
      end
    end

    RunnerUtils.info "Nagios command successful: #{command}"
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
