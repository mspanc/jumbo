defmodule Jumbo.QueueSupervisor do
  @moduledoc """
  Module that can be used to supervise many queues.

  It is supposed to be spawned as a process using `start_link/2` or `start/2`
  functions.
  """

  use Supervisor
  import Supervisor.Spec


  @doc """
  Starts the supervisor.

  It expects an argument which is a list of tuples `{name, options}`
  where:

  * name - an atom that will be used used to name individual queue process, must
    be compatible with syntax of erlang registered process names,
  * options - a `Jumbo.QueueOptions` struct.

  Returns the same values as `Supervisor.start_link/2`.
  """
  @spec start_link([] | [{atom, module, Jumbo.QueueOptions.t}]) :: Supervisor.on_start
  def start_link(queues) do
    Supervisor.start_link(__MODULE__, queues)
  end


  # Private API

  @doc false
  def init(queues) do
    children = queues |>
      Enum.map(fn({queue_name, queue_options}) ->
        worker(Jumbo.Queue, [queue_options], name: queue_name, id: queue_name)
      end)

    supervise(children, strategy: :one_for_one)
  end
end
