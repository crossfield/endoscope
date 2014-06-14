# TODO:
#  * allow configuring the transport
#  * allow configuring the namesapce

require_relative "transport"

require "timeout"
require "stringio"

module Endoscope
  class Agent
    ENDOSCOPE = "endoscope".freeze

    attr_reader :dyno_name, :redis_options

    def initialize(dyno_name, redis_options)
      @dyno_name = dyno_name
      @redis_options = redis_options || default_redis_options
    end

    def default_redis_options
      {
        url: ENV['ENDOSCOPE_REDIS_URL'] || 'redis://127.0.0.1:6379/',
        namespace: ENV['ENDOSCOPE_REDIS_NAMESPACE']
      }
    end

    def start
      Thread.new(&method(:agent_listener))
    end

    def agent_listener
      Thread.current[:name] = ENDOSCOPE
      begin
        wait_for_commands
      rescue => e
        puts e.inspect
        puts e.backtrace.join("\n")
      end
    end

    def wait_for_commands
      transport = Transport.new(redis_options)
      transport.wait_for_commands(dyno_name) do |command|
        command_received(command)
      end
    rescue Transport::ConnectionError => error
      puts "ns=endoscope at=wait_for_commands error=#{error} reconnect_in=1s"
      sleep 1
      retry
    end

    def command_received(command)
      puts "ns=endoscope at=command_received"
      to_eval = command.fetch('command')
      result = evaluate(to_eval)
      Transport.new(redis_options).publish_response(command, dyno_name, result)
    end

    EvalTimeout = Class.new(Timeout::Error)

    def evaluate(ruby)
      capture_streams do |out|
        begin
          Timeout.timeout(10, EvalTimeout) do
            # rubocop:disable Eval
            res = eval(ruby, TOPLEVEL_BINDING, 'remote_command')
            # rubocop:enable Eval
            out.puts res.inspect
          end
        rescue Exception => e
          out.puts(e.inspect, *e.backtrace)
        end
      end
    end

    def capture_streams
      $old_stdout = $stdout
      $old_stderr = $stderr

      out = StringIO.new
      $stdout = out
      $stderr = out
      yield(out)

      out.rewind
      out.read
    ensure
      $stdout = $old_stdout
      $stderr = $old_stderr
    end
  end
end
