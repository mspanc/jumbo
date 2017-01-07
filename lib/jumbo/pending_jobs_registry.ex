defmodule Jumbo.PendingJobsRegistry do
  @moduledoc false

  alias Jumbo.JobId
  alias Jumbo.PendingJob
  alias Jumbo.PendingJobsRegistry

  @behaviour Jumbo.JobRegistry


  @type t :: %PendingJobsRegistry{
    jobs: MapSet.t,
    count: non_neg_integer,
    ids: MapSet.t,
  }


  defstruct \
    jobs: MapSet.new,
    count: 0,
    ids: MapSet.new


  @spec put(PendingJobsRegistry.t, JobId.t, Job.module_t, Job.args_t) :: PendingJobsRegistry.t
  def put(%PendingJobsRegistry{jobs: jobs, count: count, ids: ids}, id, module, args) do
    %PendingJobsRegistry{
      jobs: jobs |> MapSet.put(%PendingJob{id: id, module: module, args: args, enqueued_at: :erlang.monotonic_time()}),
      count: count + 1,
      ids: ids |> MapSet.put(id),
    }
  end


  @spec count(PendingJobsRegistry.t) :: non_neg_integer
  def count(%PendingJobsRegistry{count: count}) do
    count
  end


  @spec get_ids(PendingJobsRegistry.t) :: MapSet.t
  def get_ids(%PendingJobsRegistry{ids: ids}) do
    ids
  end


  @spec get_jobs(PendingJobsRegistry.t) :: [] | [PendingJob.t]
  def get_jobs(%PendingJobsRegistry{jobs: jobs}) do
    jobs |> MapSet.to_list
  end


  @spec pop(PendingJobsRegistry.t) :: {:ok, {nil | PendingJob.t, PendingJobsRegistry.t}}
  def pop(%PendingJobsRegistry{jobs: jobs, count: count, ids: ids} = registry) do
    case jobs |> MapSet.to_list() do
      [] ->
        {:ok, {nil, registry}}

      [%PendingJob{id: id} = head|_rest] ->
        new_registry = %PendingJobsRegistry{
          jobs: jobs |> MapSet.delete(head),
          count: count - 1,
          ids: ids |> MapSet.delete(id),
        }

        {:ok, {head, new_registry}}
    end
  end
end
