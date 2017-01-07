defmodule Jumbo.FailedJob do
  @moduledoc """
  Structure representing a single job that has failed and is waiting for retry.

  It has the following fields:

  * id: String containing job unique ID in the UUIDv4 format,
  * module: module that is being called when running the job,
  * args: list of arguments that are applied to module's perform function when
    running the job,
  * failure_count: integer telling how many times this job has failed,
  * reason: atom telling why job has failed, if it is `:throw` it means that
    some term was thrown, `:raise` means that exception was raised, `:killed`
    means that process has been killed,
  * info: for reason set to `:throw` it is an atom that was thrown, for reason
    set to `:raise` it is an exception that was raised, `nil` otherwise,
  * stacktrace: for reason set to `:throw` or `:raise` it will contain a list,
    of tuples with stack trace,
  * failed_at: time when job was moved to failing state, in format returned by
    `:erlang.monotonic_time/0`.
  """

  alias Jumbo.JobId

  @type reason_t :: :throw | :raise | :killed
  @type info_t :: any
  @type stacktrace_t :: [{tuple}]

  @type t :: %Jumbo.FailedJob{
    id: JobId.t,
    module: module,
    args: [] | [any],
    failure_count: pos_integer,
    reason: reason_t,
    info: info_t | nil,
    stacktrace: stacktrace_t | nil,
    failed_at: integer,
  }


  defstruct \
    id: nil,
    module: nil,
    args: [],
    failure_count: 1,
    info: nil,
    reason: nil,
    stacktrace: nil,
    failed_at: nil
end
