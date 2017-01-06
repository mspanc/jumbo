# Jumbo - A surprisingly thin job queue for Elixir

[![Build Status](https://travis-ci.org/mspanc/jumbo.svg?branch=master)](https://travis-ci.org/mspanc/jumbo)
[![Coverage Status](https://coveralls.io/repos/github/mspanc/jumbo/badge.svg?branch=master)](https://coveralls.io/github/mspanc/jumbo?branch=master)
[![Hex.pm](https://img.shields.io/hexpm/v/jumbo.svg)](https://hex.pm/packages/jumbo)
[![Hex.pm](https://img.shields.io/hexpm/dt/jumbo.svg)](https://hex.pm/packages/jumbo)

Jumbo is a job queue for the [Elixir](http://www.elixir-lang.org) language.

At the moment it does not support persistency but it may be added in the future.


## Goals

### Reliability

First of all, job processing queue must be reliable even under high workloads.
Needless to comment.

### Using OTP goodness as much as it is possible

Many existing, similar projects tend to reinvent the wheel. OTP and standard
library already contains most of the tools that is needed to build a reliable
queue. It is not necessary to use external DB such as Redis to do locking, or
avoid other corner cases. In fact, Jumbo is a wrapper around GenServer.

In other projects there are also some DSLs for definining and managing the
individual queues. Here, each queue is just a process.

### Not necessarily persistent

Persistency can be cool but when the whole mechanism has to be built around it,
IMO it means that something went wrong. Current version of Jumbo does not support
persistency, but its architecture will allow do add it easily in the future
without compromising queueing logic based on OTP. Moreover, it might be configured
per-queue, yay!

### Lightweight

It should be as light as possible. If you launch millions of jobs, you don't want
your queue engine to be a bottleneck.


## Usage

Add dependency to your `mix.exs`:

```elixir
defp deps do
  [{:jumbo, "~> 1.0.0"}]
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
      worker(Joint.Queue, [
        %Jumbo.QueueOptions{},
        [name: SampleApp.QueueHeavy]]
      ),
      # Queue for light tasks
      worker(Joint.Queue, [
        %Jumbo.QueueOptions{},
        [name: SampleApp.QueueLight]]
      ),
    ]

    opts = [strategy: :one_for_one, name: SampleApp]
    Supervisor.start_link(children, opts)
  end
end
```

then in your code you can define a job module:

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
Joint.Queue.enqueue(SampleApp.QueueLight, ["hello"])
```


## Versioning

Project follows [Semantic Versioning](http://semver.org/).

## Author


Marcin Lewandowski <marcin@saepia.net>


## License

MIT
