defmodule Jumbo.FailedJobsRegistry do
  @moduledoc false

  alias Jumbo.FailedJob
  alias Jumbo.FailedJobsRegistry

  @behaviour Jumbo.JobRegistry


  @type t :: %FailedJobsRegistry{
    jobs: MapSet.t,
    count: non_neg_integer,
    ids: MapSet.t,
  }


  defstruct \
    jobs: MapSet.new,
    count: 0,
    ids: MapSet.new


  @spec put(FailedJobsRegistry.t, Job.id_t, Job.module_t, Job.args_t, FailedJob.reason_t, FailedJob.info_t, FailedJob.stacktrace_t) :: FailedJobsRegistry.t
  def put(%FailedJobsRegistry{jobs: jobs, count: count, ids: ids}, id, module, args, reason, info \\ nil, stacktrace \\ nil, failure_count \\ 1) do
    %FailedJobsRegistry{
      jobs: jobs |> MapSet.put(%FailedJob{id: id, module: module, args: args, reason: reason, info: info, stacktrace: stacktrace, failed_at: :erlang.monotonic_time(), failure_count: failure_count}),
      count: count + 1,
      ids: ids |> MapSet.put(id),
    }
  end


  @spec count(FailedJobsRegistry.t) :: non_neg_integer
  def count(%FailedJobsRegistry{count: count}) do
    count
  end


  @spec get_ids(FailedJobsRegistry.t) :: MapSet.t
  def get_ids(%FailedJobsRegistry{ids: ids}) do
    ids
  end


  @spec get_jobs(FailedJobsRegistry.t) :: [] | [FailedJob.t]
  def get_jobs(%FailedJobsRegistry{jobs: jobs}) do
    jobs |> MapSet.to_list
  end


  @spec pop_many(FailedJobsRegistry.t) :: {:ok, {[] | [FailedJob.t], FailedJobsRegistry.t}}
  def pop_many(%FailedJobsRegistry{jobs: jobs} = registry) do
    case jobs |> MapSet.to_list() do
      [] ->
        {:ok, {[], registry}}

      failed_jobs ->
        # Filter out jobs that are not waiting long enough after last failure.
        #
        # For each failure wait for 3 seconds longer than from previous failure.
        # So after 1st failure it will wait 3s, after 2nd failure it will wait
        # 6s, (9s from first in total) etc.
        failed_jobs_ready = Enum.reject(failed_jobs, fn(%FailedJob{failed_at: failed_at, failure_count: failure_count}) ->
          (:erlang.monotonic_time() - failed_at) |> div(:erlang.convert_time_unit(1, :seconds, :native) * 3) < failure_count
        end)

        case failed_jobs_ready do
          [] ->
            {:ok, {[], registry}}

          failed_jobs_ready ->
            {failed_jobs, new_registry} = failed_jobs_ready
              |> Enum.reduce({[], registry}, fn(%FailedJob{id: id} = failed_job, {acc_failed_jobs, acc_registry}) ->
                %FailedJobsRegistry{jobs: jobs, count: count, ids: ids} = acc_registry

                new_registry = %FailedJobsRegistry{
                  jobs: jobs |> MapSet.delete(failed_job),
                  count: count - 1,
                  ids: ids |> MapSet.delete(id),
                }

                {[failed_job|acc_failed_jobs], new_registry}
              end)

            {:ok, {failed_jobs, new_registry}}
        end
    end
  end


  @spec pop(FailedJobsRegistry.t) :: {:ok, {nil | FailedJob.t, FailedJobsRegistry.t}}
  def pop(%FailedJobsRegistry{jobs: jobs, count: count, ids: ids} = registry) do
    case jobs |> MapSet.to_list() do
      [] ->
        {:ok, {nil, registry}}

      failed_jobs ->
        # Filter out jobs that are not waiting long enough after last failure.
        #
        # For each failure wait for 3 seconds longer than from previous failure.
        # So after 1st failure it will wait 3s, after 2nd failure it will wait
        # 6s, (9s from first in total) etc.
        failed_jobs_ready = Enum.reject(failed_jobs, fn(%FailedJob{failed_at: failed_at, failure_count: failure_count}) ->
          (:erlang.monotonic_time() - failed_at) |> div(:erlang.convert_time_unit(1, :seconds, :native) * 3) < failure_count
        end)

        case failed_jobs_ready do
          [] ->
            {:ok, {nil, registry}}

          [%FailedJob{id: id} = head|_rest] ->
            new_registry = %FailedJobsRegistry{
              jobs: jobs |> MapSet.delete(head),
              count: count - 1,
              ids: ids |> MapSet.delete(id),
            }

            {:ok, {head, new_registry}}
        end
    end
  end
end
