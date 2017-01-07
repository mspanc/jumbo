defmodule Jumbo.QueueOptions do
  @moduledoc """
  Structure representing options that can be passed to `Jumbo.Queue` upon
  initialization.

  It has the following fields:

  * concurrency: non-negative integer telling how many concurrent jobs can
    be running simulanously for this queue (defaults to 1),
  * poll_interval: positive integer expressing interval in milliseconds,
    how often the queue should check if there are no failed or scheduled jobs
    to enqueue (defaults to 1000),
  * logger_tag: string that should be appended to all log messages from this
    queue, or `nil`,
  * max_failure_count: non-negative integer telling how many times failed jobs,
    will be retried before removing them from the queue (defaults to 20).

  # TODO: add on_start fun
  """

  alias Jumbo.QueueOptions

  @type concurrency_t  :: non_neg_integer
  @type poll_interval  :: pos_integer
  @type logger_tag_t   :: String.t | nil
  @type max_failure_count_t :: non_neg_integer

  @type t :: %QueueOptions{
    concurrency: concurrency_t,
    poll_interval: poll_interval,
    logger_tag: logger_tag_t,
    max_failure_count: max_failure_count_t,
  }

  defstruct \
    concurrency: 1,
    poll_interval: 1000,
    logger_tag: nil,
    max_failure_count: 20
end
