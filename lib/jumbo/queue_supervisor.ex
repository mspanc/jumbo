defmodule Jumbo.QueueSupervisor do
  @moduledoc """
  Module that can be used to supervise many queues.

  It is supposed to be spawned as a process using `start_link/2` function.

  ## Usage with OTP application

  If you want to add it to your OTP app, you may do this as following:

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
  """

  use Supervisor
  import Supervisor.Spec


  @doc """
  Starts the supervisor.

  It expects an argument which is a list of tuples `{name, options}`
  where:

  * name - an atom that will be used used to name individual queue process, must
    be compatible with syntax of erlang registered process names,
  * process_options - a `Supervisor.options` struct.

  Returns the same values as `Supervisor.start_link/2`.
  """
  @spec start_link([] | [{atom, module, Jumbo.QueueOptions.t}], Supervisor.options) :: Supervisor.on_start
  def start_link(queues, process_options \\ []) do
    Supervisor.start_link(__MODULE__, queues, process_options)
  end


  # Private API

  @doc false
  def init(queues) do
    children = queues |>
      Enum.map(fn({queue_name, queue_options}) ->
        worker(Jumbo.Queue, [queue_options, [name: queue_name]], [id: queue_name])
      end)

    supervise(children, strategy: :one_for_one)
  end
end
