defmodule Jumbo.QueueOptions do
  @moduledoc """
  Structure representing options that can be passed to `Jumbo.Queue` upon
  initialization.

  You have to pick up queueing mode, by setting up the `mode` field.

  * if it is set to `:concurrency` (default), the queue will concurrently run
    jobs, as fast as it can, up to a limit specified in the `concurrency` field
    (defaults to 1).
  * if it is set to `:job_interval`: the queue will allow only one job to be
    running at a time, and will guarnantee that at least certain interval will
    pass between jobs (defaults to 1000 ms).

  The first mode is the most common use case.

  Second may be useful if e.g. your application needs to talk to the external
  API which as really small rate limits. In such case keeping concurrency low
  and retrying failed jobs will be not enough as such jobs can form a tsunami
  of jobs that will still be hitting the API frequently.

  Moreover, it has the following fields that apply to all modes:

  * poll_interval: positive integer expressing interval in milliseconds,
    how often the queue should check if there are no failed or scheduled jobs
    to enqueue (defaults to 1000),
  * stats_interval: positive integer expressing interval in milliseconds,
    how often the queue should collect statistics (defaults to 60000),
  * logger_tag: string that should be appended to all log messages from this
    queue, or `nil`,
  * max_failure_count: non-negative integer telling how many times failed jobs,
    will be retried before removing them from the queue (defaults to 20).
  """

  alias Jumbo.QueueOptions

  @type mode_t              :: :concurrency | :job_interval
  @type concurrency_t       :: non_neg_integer | nil
  @type job_interval_t      :: non_neg_integer | nil
  @type poll_interval_t     :: pos_integer
  @type stats_interval_t    :: pos_integer
  @type logger_tag_t        :: String.t | nil
  @type max_failure_count_t :: non_neg_integer

  @type t :: %QueueOptions{
    mode: mode_t,
    concurrency: concurrency_t,
    job_interval: job_interval_t,
    poll_interval: poll_interval_t,
    stats_interval: stats_interval_t,
    logger_tag: logger_tag_t,
    max_failure_count: max_failure_count_t,
  }

  defstruct \
    mode: :concurrency,
    concurrency: 1,
    job_interval: 1000,
    poll_interval: 1000,
    stats_interval: 60000,
    logger_tag: nil,
    max_failure_count: 20
end
