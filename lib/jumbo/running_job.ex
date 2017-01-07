defmodule Jumbo.RunningJob do
  @moduledoc """
  Structure representing a single job that is currently running.

  It has the following fields:

  * id: String containing job unique ID in the UUIDv4 format,
  * pid: PID of the process actually running the job,
  * module: module that is being called when running the job,
  * args: list of arguments that are applied to module's perform function when
    running the job,
  * started_at: time when job was started, in format returned by
    `:erlang.monotonic_time/0`,
  * failure_count: integer telling how many times this job has failed.
  """

  alias Jumbo.JobId


  @type t :: %Jumbo.RunningJob{
    id: JobId.t,
    pid: pid,
    module: module,
    args: [] | [any],
    started_at: integer,
    failure_count: pos_integer,
  }


  defstruct \
    id: nil,
    pid: nil,
    module: nil,
    args: [],
    started_at: nil,
    failure_count: 0
end
