# Endoscope

Remote shell for live interaction with Ruby processes

## Installation

Add this line to your application's Gemfile:

    gem 'endoscope'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install endoscope

## Usage

You need to start the endoscope agent when your application boots up, naming this process.

For example, in a Rails app this could go in `config/initializers/endoscope.rb`

```ruby
require "endoscope"

process_name = if dyno = ENV['DYNO'] || ENV['PS']
  Process.pid == 2 ? dyno : "#{dyno}-child-#{Process.pid}"
else
  progname = $PROGRAM_NAME.gsub(Rails.root.to_s + '/', '')
  "#{progname}:#{Process.pid}"
end

# using ENV['ENDOSCOPE_REDIS_URL'] and ENV['ENDOSCOPE_REDIS_NAMESPACE']
Endoscope::Agent.new(process_name).start
```

You can also use a redis connection configuration as expected by the redis gem.

You can then use the Endoscope shell to interact with your app.
For example, on a running Heroku app comprising of web, sidekiq and
sidekiq-scheduler dynos:

```
bundle exec endoscope
>> 40 + 2
40 + 2
Sending command 40 + 2...

From web.1-child-6 :
42

From web.2-child-9 :
42

From web.1-child-9 :
42

From worker.1 :
42

From web.1-child-13 :
42

From web.2-child-6 :
42

From web.2-child-13 :
42

From scheduler.1 :
42

```

You can direct your commands at select process types or processes via
the `use command`

```
>> use web
Now adressing commands to processes listening for "web".
>> use worker.1
Now adressing commands to processes listening for "worker.1".
>> use all
Now adressing commands to processes listening for "all".
```

## Common uses
* retrieving garbage collection stats
* Taking thread dumps
* Re-open classes, redefining method to test changes / add logging without needing to commit and re-deploy
* adjust logging verbosity
* toggle features while debugging to narrow down the possible error causes


## Notes

* The endoscope communication happens securely over Redis PubSub.
* The commands are evaluated in the top level binding of the instrumented program.
* stdout and stderr outputs are captured while the command is evaluated.
* Commands evaluation exceptions are caught and reported via the endoscope.
* Commands evaluation is protected by an execution timeout of 10 seconds.
* The agent starts a ruby thread with no overhead while not evaluating remote commands.

## Contributing

1. Fork it ( https://github.com/preplay/endoscope/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
