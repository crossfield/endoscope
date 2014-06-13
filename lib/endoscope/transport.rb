require_relative "../endoscope"

require "redis"
require "json"

module Endoscope
  class Transport
    ConnectionError = Class.new(RuntimeError)
    
    attr_reader :namespace, :redis_opts
    def initialize(opts)
      @namespace = opts.delete(:namespace) || "endoscope"
      @redis_opts = opts
    end
    
    def wait_for_commands(dyno_name)
      channels = command_channels(dyno_name)
      connection.subscribe(*channels) do |on|
        on.message do |_channel, message|
          # puts "##{channel}: #{message}"
          command = JSON.parse(message)
          yield(command)
        end
      end
    rescue Redis::BaseConnectionError => error
      raise ConnectionError, error.message, error
    end
    
    def send_command(command_id, command, dyno_selector)
      channel = requests_channel(dyno_selector)
      connection.publish(channel, JSON.generate(
        id: command_id,
        command: command,
        channel: channel
      ))
    end

    def publish_response(command, dyno_name, result)
      connection.publish(responses_channel, JSON.generate(
        id: command.fetch('id'),
        command: command.fetch('command'),
        dyno_name: dyno_name,
        result: result
      ))
    end

    def listen_to_responses
      connection.subscribe(responses_channel) do |on|
        on.message do |_channel_name, response|
          yield(response)
        end
      end
      
    end
    
    private

    def connection
      @connection ||= Redis.connect(redis_opts)
    end

    ALL = "all".freeze
    def command_channels(dyno)
      type = dyno.split('.', 2).first
      [requests_channel(type), requests_channel(dyno), requests_channel(ALL)]
    end

    def requests_channel(selector)
      "#{namespace}:requests:#{selector}"
    end

    def responses_channel
      "#{namespace}:responses"
    end

  end
end
    
  