defmodule Jumbo.QueueState do
  @moduledoc false
  # Private module
  #
  # Struct representing internal state of `Jumbo.Queue` process.

  alias Jumbo.QueueState
  alias Jumbo.QueueOptions
  alias Jumbo.PendingJobsRegistry
  alias Jumbo.RunningJobsRegistry
  alias Jumbo.FailedJobsRegistry


  @type t :: %QueueState{
    mode: QueueOptions.mode_t,
    concurrency: QueueOptions.concurrency_t,
    job_interval: QueueOptions.job_interval_t,
    poll_interval: QueueOptions.poll_interval_t,
    stats_interval: QueueOptions.stats_interval_t,
    logger_tag: QueueOptions.logger_tag_t,
    max_failure_count: QueueOptions.max_failure_count_t,
    pending_jobs: PendingJobsRegistry.t,
    running_jobs: RunningJobsRegistry.t,
    failed_jobs: FailedJobsRegistry.t,
    supervisor: Task.Supervisor.t,
    poll_timer: reference,
    stats_timer: reference,
  }

  defstruct \
    mode: nil,
    concurrency: nil,
    job_interval: nil,
    poll_interval: nil,
    stats_interval: nil,
    logger_tag: nil,
    max_failure_count: nil,
    pending_jobs: struct(PendingJobsRegistry),
    running_jobs: struct(RunningJobsRegistry),
    failed_jobs: struct(FailedJobsRegistry),
    supervisor: nil,
    poll_timer: nil,
    stats_timer: nil
end
