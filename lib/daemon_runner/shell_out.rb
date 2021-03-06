require 'mixlib/shellout'

module DaemonRunner
  class ShellOut
    attr_reader :runner, :stdout
    attr_reader :command, :cwd, :timeout, :wait, :valid_exit_codes

    # Wait for the process with the given pid to finish
    # @param pid [Fixnum] the pid to wait on
    # @param flags [Fixnum] flags to Process.wait2
    # @return [Process::Status, nil] the process status or nil if no process was found
    def self.wait2(pid = nil, flags = 0)
      return nil if pid.nil?
      Process.wait2(pid, flags)[1]
    rescue Errno::ECHILD
      nil
    end

    # @param command [String] the command to run
    # @param cwd [String] the working directory to run the command
    # @param timeout [Fixnum] the command timeout
    # @param wait [Boolean] wheather to wait for the command to finish
    # @param valid_exit_codes [Array<Fixnum>] exit codes that aren't flagged as failures
    def initialize(command: nil, cwd: '/tmp', timeout: 15, wait: true, valid_exit_codes: [0])
      @command = command
      @cwd = cwd
      @timeout = timeout
      @wait = wait
      @valid_exit_codes = valid_exit_codes
    end

    # Run command
    # @return [Mixlib::ShellOut, Fixnum] mixlib shellout client or a pid depending on the value of {#wait}
    def run!
      validate_command
      if wait
        run_and_wait
      else
        run_and_detach
      end
    end

    # Wait for the process to finish
    # @param flags [Fixnum] flags to Process.wait2
    # @return [Process::Status, nil] the process status or nil if no process was found
    def wait2(flags = 0)
      self.class.wait2(@pid, flags)
    end

    private

    # Run a command and wait for it to finish
    # @return [Mixlib::ShellOut] client
    def run_and_wait
      validate_args
      runner
      @runner.run_command
      @runner.error!
      @stdout = @runner.stdout
      @runner
    end

    # Run a command in a new process group, thus ignoring any furthur
    # updates about the status of the process
    # @return [Fixnum] process id
    def run_and_detach
      log_r, log_w = IO.pipe
      @pid = Process.spawn(command, pgroup: true, err: :out, out: log_w)
      log_r.close
      log_w.close
      @pid
    end

    # Validate command is defined before trying to start the command
    # @ raise [ArgumentError] if any of the arguments are missing
    def validate_command
      if @command.nil? && !respond_to?(:command)
        raise ArgumentError, 'Must pass a command or implement a command method'
      end
    end

    # Validate arguments before trying to start the command
    # @ raise [ArgumentError] if any of the arguments are missing
    def validate_args
      if @cwd.nil? && !respond_to?(:cwd)
        raise ArgumentError, 'Must pass a cwd or implement a cwd method'
      end

      if @timeout.nil? && !respond_to?(:timeout)
        raise ArgumentError, 'Must pass a timeout or implement a timeout method'
      end
    end

    # Setup a new Mixlib::ShellOut client runner
    # @return [Mixlib::ShellOut] client
    def runner
      @runner = Mixlib::ShellOut.new(command, :cwd => cwd, :timeout => timeout)
      @runner.valid_exit_codes = valid_exit_codes
    end
  end
end
