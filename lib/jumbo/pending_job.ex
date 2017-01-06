defmodule Jumbo.PendingJob do
  @moduledoc """
  Structure representing a single job that is pending for free slot in the queue.

  It has the following fields:

  * id: String containing job unique ID in the UUIDv4 format,
  * module: module that is being called when running the job,
  * args: list of arguments that are applied to module's perform function when
    running the job,
  * failure_count: non-ngative integer telling how many times this job has
    failed in the past,
  * enqueued_at: time when job was moved to the pending queue, in format
    returned by `:erlang.monotonic_time/0`.
  """


  alias Jumbo.Job


  @type t :: %Jumbo.PendingJob{
    id: Job.id_t,
    module: module,
    args: [] | [any],
    failure_count: pos_integer,
    enqueued_at: integer,
  }


  defstruct \
    id: nil,
    module: nil,
    args: [],
    failure_count: 0,
    enqueued_at: nil
end
