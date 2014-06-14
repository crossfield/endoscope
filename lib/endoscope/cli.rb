require_relative "../endoscope"
require_relative "transport"

require "set"
require 'securerandom'

module Endoscope
  class CLI
    attr_accessor :dyno_selector, :issued, :transport_opts

    def initialize(transport_opts=nil)
      @transport_opts = transport_opts
    end

    def start(dyno_selector = 'all')
      @dyno_selector = dyno_selector
      @issued = Set.new
      start_responses_printing_thread
      transport
      start_shell
    end

    def start_shell
      begin
        require "ripl"
        require "ripl/ripper"
      rescue LoadError => err
        puts err.message
        abort("\nYou need to run:\n\ngem install ripl ripl-ripper\n\nThen launch this command again.")
      end

      cli = self
      Ripl::Shell.send(:define_method, :loop_eval) { |str| cli.eval_(str) }
      Ripl::Shell.send(:define_method, :print_result) { |_result| }
      Ripl.start( argv: [], irbrc: false, riplrc: false, ripper_prompt: ' | ')
    end

    def start_responses_printing_thread
      @responses_thread = Thread.new(&method(:responses_printer))
    end

    def responses_printer
      Thread.current[:name] = 'endoscope-responses-printing'
      listen_to_command_responses
    end

    def listen_to_command_responses
      transport = Transport.new(transport_opts)
      transport.listen_to_responses do |response|
        handle_response(response)
      end
    rescue Redis::TimeoutError => _
      retry
    rescue => err
      puts err.inspect
      puts err.backtrace.join("\n")
    end

    def handle_response(res)
      #p res
      #p issued
      #p res['id']
      return unless issued.include?(res['id'])
      puts "From #{res['dyno_name']} :\n#{res['result']}\n\n"
      $stdout.flush
    end

    def repl
      catch(:break) do
        puts "\n\n ---\nRemote console ready:\n\n"
        $stdout.flush
        loop { re($stdout) }
      end
    end

    def re(out = $stdout)
      command = read
      eval_(command, out)
    rescue Interrupt
      throw(:break)
    end

    def eval_(command, out = $stdout)
      case command
      when 'exit'
        throw(:break)
      when /^use /
        @dyno_selector = command.gsub('use ', '').strip
        puts "Now adressing commands to processes listening for #{dyno_selector.inspect}."
      else
        send_command(command, out) unless command.nil? || command.strip == ''
      end
    end

    def read
      read = gets
      read && read.chomp
    end

    def transport
      @transport ||= begin
        Transport.new(transport_opts)
      end
    end

    def send_command(command, _out = $stdout)
      puts "Sending command #{command}..."
      command_id = SecureRandom.uuid
      issued << command_id

      transport.send_command(command_id, command, dyno_selector)
    end
  end
end
