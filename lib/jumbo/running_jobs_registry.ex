defmodule Jumbo.RunningJobsRegistry do
  @moduledoc false

  alias Jumbo.JobId
  alias Jumbo.RunningJob
  alias Jumbo.RunningJobsRegistry

  @behaviour Jumbo.JobRegistry


  @type t :: %RunningJobsRegistry{
    jobs: %{required(reference) => RunningJob.t},
    count: non_neg_integer,
    ids: MapSet.t,
  }


  defstruct \
    jobs: %{},
    count: 0,
    ids: MapSet.new


  @spec put(RunningJobsRegistry.t, JobId.t, reference, pid, Job.module_t, Job.args_t, non_neg_integer) :: RunningJobsRegistry.t
  def put(%RunningJobsRegistry{jobs: jobs, count: count, ids: ids}, id, ref, pid, module, args, failure_count \\ 0) do
    %RunningJobsRegistry{
      jobs: jobs |> Map.put(ref,
        %RunningJob{
          id: id,
          pid: pid,
          module: module,
          args: args,
          started_at: :erlang.monotonic_time(),
          failure_count: failure_count,
        }
      ),
      count: count + 1,
      ids: ids |> MapSet.put(id),
    }
  end


  @spec count(RunningJobsRegistry.t) :: non_neg_integer
  def count(%RunningJobsRegistry{count: count}) do
    count
  end


  @spec get_ids(RunningJobsRegistry.t) :: MapSet.t
  def get_ids(%RunningJobsRegistry{ids: ids}) do
    ids
  end


  @spec get_jobs(RunningJobsRegistry.t) :: [] | [RunningJob.t]
  def get_jobs(%RunningJobsRegistry{jobs: jobs}) do
    jobs |> Map.values()
  end


  @spec get_by_ref(RunningJobsRegistry.t, reference) :: RunningJob.t
  def get_by_ref(%RunningJobsRegistry{jobs: jobs}, ref) do
    jobs |> Map.get(ref)
  end


  @spec delete_by_ref(RunningJobsRegistry.t, reference) :: RunningJob.t
  def delete_by_ref(%RunningJobsRegistry{jobs: jobs, count: count, ids: ids}, ref) do
    %RunningJob{id: id} = jobs |> Map.get(ref)

    %RunningJobsRegistry{
      jobs: jobs |> Map.delete(ref),
      count: count - 1,
      ids: ids |> MapSet.delete(id)
    }
  end
end
