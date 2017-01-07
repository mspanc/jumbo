# Jumbo - A surprisingly thin job queue for Elixir

[![Build Status](https://travis-ci.org/mspanc/jumbo.svg?branch=master)](https://travis-ci.org/mspanc/jumbo)
[![Coverage Status](https://coveralls.io/repos/github/mspanc/jumbo/badge.svg?branch=master)](https://coveralls.io/github/mspanc/jumbo?branch=master)
[![Hex.pm](https://img.shields.io/hexpm/v/jumbo.svg)](https://hex.pm/packages/jumbo)
[![Hex.pm](https://img.shields.io/hexpm/dt/jumbo.svg)](https://hex.pm/packages/jumbo)

Jumbo is a job queue for the [Elixir](http://www.elixir-lang.org) language.

At the moment it does not support persistency but it may be added in the future.


## Goals

### Reliability

First of all, job processing queue must be reliable even under high workloads
and handle all sorts of reasons for failing jobs. Jumbo will survive throwing
terms, raising exceptions and even job processes performing seppuku by sending
`Process.exit(self(), :kill)`!

### Using OTP goodness as much as it is possible

Many existing, similar projects tend to reinvent the wheel. OTP and standard
library already contains most of the tools that are needed to build a reliable
queue. It is not necessary to use external DB such as Redis to do locking, keep
list of jobs or do other stuff. In fact, Jumbo is a wrapper around GenServer
and a Task.

In other projects there are also some DSLs for defining and managing the
individual queues which add unnecessary, non-standard abstraction layer.
Here, each queue is just a process that you can call similarly to how you use
GenServer. It perfectly fits into your application and you can use it Erlang way.
Need to spawn a queue while app is running? No problem, `Jumbo.Queue.start_link/2`
is waiting for you.

### Not necessarily persistent

Persistency can be cool but when the whole queueing mechanism has to be built
around it, IMO it means that something went wrong. Current version of Jumbo does
not support persistency, but its architecture will allow do add it easily in the
future without compromising queueing logic based on OTP. Moreover, it might be
configured per-queue, yay!

### Lightweight

It should be as light as possible. If you launch millions of jobs, you don't want
your queue engine to be a bottleneck.

## TODO

Hey this is 1.0.0, don't expect too much, some things may be still improved!

### Memory usage

At the moment jobs are stored just in underlying GenServer's state which may
result in high memory usage in case of many jobs. Should be improved once
ETS tables will be used for storing jobs.

### Job polling

At the moment jobs are stored just in underlying GenServer's state which may
result in bad access times in case of many jobs. Should be improved once
ETS tables will be used for storing jobs.

### Code coverage

Specs are cool thing to have, definitely!

### Web UI

Just useful.

### API changes/additions

There are some upcoming breaking API changes.

* `Jumbo.Queue.enqueue/3` should return `{:ok, job_id}` instead of `:ok`,
* `Jumbo.Queue.enqueue/3` should accept MFA [as suggested on ElixirForum](https://elixirforum.com/t/jumbo-new-job-queueing-library/3170/4?u=mspanc),
* `Jumbo.Queue.get_*_jobs/2` should allow to fetch paginated jobs for showing them efficiently in the upcoming Web UI.
* New `Jumbo.QueueBehaviour` for defining custom queue modules with callbacks.
* Add option to limit job per time unit per queue (useful for external API requests throttling - concurrency = 1 can be still too fast).

Please create an Issue if you have any further suggestions.

### Statistics

Queue should maintain per-queue statistics.


## Usage

Add dependency to your `mix.exs`:

```elixir
defp deps do
  [{:jumbo, "~> 1.0"}]
end
```

If you use Elixir < 1.4, add it to your OTP application list:

```elixir
def application do
  [
    applications: [:logger, :jumbo],
    # more apps...
  ]
end
```

Elixir 1.4 and newer will automatically detect the application and add it
to your application list unless you manually override it.

Then you can set some queues to start upon application boot:

```elixir
defmodule SampleApp do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # Queue for heavy tasks
      worker(Jumbo.Queue, [
        %Jumbo.QueueOptions{},
        [name: SampleApp.Queue.Heavy]
      ], [id: :heavy]),

      # Queue for light tasks
      worker(Jumbo.Queue, [
        %Jumbo.QueueOptions{},
        [name: SampleApp.Queue.Light]
      ], [id: :light]),
    ]

    opts = [strategy: :one_for_one, name: SampleApp]
    Supervisor.start_link(children, opts)
  end
end
```

however, better idea may be to add a supervisor, instead of directly linking
queue processes to your application:

```elixir
defmodule SampleApp do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      supervisor(Jumbo.QueueSupervisor, [[
        {
          SampleApp.Queue.Heavy,
          %Jumbo.QueueOptions{concurrency: 8, logger_tag: "heavy"},
        }, {
          SampleApp.Queue.Light,
          %Jumbo.QueueOptions{concurrency: 16, logger_tag: "light"},
        }
      ], [name: SampleApp.QueueSupervisor]]),
    ]

    opts = [strategy: :one_for_one, name: SampleApp]
    Supervisor.start_link(children, opts)
  end
end
```

Names in the code snippeds above are just regular Erlang registered process names.
Any value recognized by Erlang as a valid registered process name will work.

Then in your code you can define a job module:

```elixir
defmodule SampleApp.SampleSleepJob do
  def perform(message) do
    :timer.sleep(2000)
    IO.puts message
  end
end
```

and enqueue it:

```elixir
Jumbo.Queue.enqueue(SampleApp.Queue.Light, SampleApp.SampleSleepJob, ["hello"])
```


## Versioning

Project follows [Semantic Versioning](http://semver.org/).

## Author


Marcin Lewandowski <marcin@saepia.net>


## License

MIT
