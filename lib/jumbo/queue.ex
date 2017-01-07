defmodule Jumbo.Queue do
  @moduledoc """
  Module that holds logic of single job processing queue.

  It is supposed to be spawned as a process using `start_link/2` or `start/2`
  functions.

  See `Jumbo.QueueOptions` for description of options that can be passed to such
  calls in order to customize queue's behaviour.

  ## Usage with OTP application

  If you want to add it to your OTP app, you may do this as following:

      defmodule SampleApp do
        use Application

        def start(_type, _args) do
          import Supervisor.Spec, warn: false

          children = [
            # Queue for heavy tasks
            worker(Jumbo.Queue, [
              %Jumbo.QueueOptions{},
              [name: SampleApp.Queue.Heavy]
            ], [id: :heavy]),

            # Queue for light tasks
            worker(Jumbo.Queue, [
              %Jumbo.QueueOptions{},
              [name: SampleApp.Queue.Light]
            ], [id: :light]),
          ]

          opts = [strategy: :one_for_one, name: SampleApp]
          Supervisor.start_link(children, opts)
        end
      end

  However, please note that using `Jumbo.QueueSupervisor` may be a better idea.
  """


  use GenServer
  alias Jumbo.QueueState
  alias Jumbo.QueueOptions
  alias Jumbo.JobRegistry
  alias Jumbo.RunningJob
  alias Jumbo.RunningJobsRegistry
  alias Jumbo.PendingJob
  alias Jumbo.PendingJobsRegistry
  alias Jumbo.FailedJob
  alias Jumbo.FailedJobsRegistry
  require Logger


  # TODO add terminate callback that that will clear the tick timer
  # and kill running jobs


  @doc """
  Starts a job queue process and links it into current process.

  It accepts queue_options argument, which should contain `Jumbo.QueueOptions`
  struct.

  It also accepts process_options argument, that works like GenServer's options.

  It returns the same return values as `GenServer.start_link/3`.
  """
  @spec start_link(QueueOptions.t, GenServer.options) :: GenServer.on_start
  def start_link(queue_options \\ %QueueOptions{}, process_options \\ []) do
    GenServer.start_link(__MODULE__, queue_options, process_options)
  end


  @doc """
  Similar to `start_link/2` but starts the queue outside of the supervision tree.
  """
  @spec start(QueueOptions.t, GenServer.options) :: GenServer.on_start
  def start(queue_options \\ %QueueOptions{}, process_options \\ []) do
    GenServer.start(__MODULE__, queue_options, process_options)
  end


  @doc """
  Enqueues given job in the given queue.

  Job is described as module and list of arguments that will be applied to the
  module's `perform` function.

  It always returns `:ok`.

  ## Example

      {:ok, queue} = Jumbo.Queue.start_link()

      defmodule SampleJob do
        def perform(x) do
          IO.puts(x)
        end
      end

      Jumbo.Queue.enqueue(queue, SampleJob, ["hello world"])

  """
  @spec enqueue(pid, QueueState.job_module_t, QueueState.job_args_t, GenServer.timeout) :: :ok
  def enqueue(server, job_module, job_args \\ [], timeout \\ 5000) do
    GenServer.call(server, {:jumbo_enqueue, {job_module, job_args}}, timeout)
  end


  @doc """
  Retreives list of running jobs from given queue.

  It returns `{:ok, running_jobs}` where running_jobs is a list of
  `Jumbo.RunningJob` structs.

  ## Example

      {:ok, queue} = Jumbo.Queue.start_link()

      {:ok, running_jobs} = Jumbo.Queue.running_jobs(queue)
      IO.puts inspect(running_jobs)

  """
  @spec get_running_jobs(pid, GenServer.timeout) :: {:ok, [] | [RunningJob.t]}
  def get_running_jobs(server, timeout \\ 5000) do
    GenServer.call(server, :jumbo_get_running_jobs, timeout)
  end


  @doc """
  Retreives list of failed jobs from given queue.

  It returns `{:ok, failed_jobs}` where failed_jobs is a list of
  `Jumbo.RunningJob` structs.

  ## Example

      {:ok, queue} = Jumbo.Queue.start_link()

      {:ok, failed_jobs} = Jumbo.Queue.failed_jobs(queue)
      IO.puts inspect(failed_jobs)

  """
  @spec get_failed_jobs(pid, GenServer.timeout) :: {:ok, [] | [RunningJob.t]}
  def get_failed_jobs(server, timeout \\ 5000) do
    GenServer.call(server, :jumbo_get_failed_jobs, timeout)
  end


  @doc """
  Retreives list of pending jobs from given queue.

  It returns `{:ok, pending_jobs}` where pending_jobs is a list of
  `Jumbo.RunningJob` structs.

  ## Example

      {:ok, queue} = Jumbo.Queue.start_link()

      {:ok, pending_jobs} = Jumbo.Queue.pending_jobs(queue)
      IO.puts inspect(pending_jobs)

  """
  @spec get_pending_jobs(pid, GenServer.timeout) :: {:ok, [] | [RunningJob.t]}
  def get_pending_jobs(server, timeout \\ 5000) do
    GenServer.call(server, :jumbo_get_pending_jobs, timeout)
  end


  # Private API

  @doc false
  @spec init(QueueOptions.t) ::
    {:ok, QueueState.t} |
    {:stop, any}
  def init(%QueueOptions{concurrency: concurrency, poll_interval: poll_interval, logger_tag: logger_tag, max_failure_count: max_failure_count}) do
    case Task.Supervisor.start_link() do
      {:ok, supervisor} ->
        {:ok, %QueueState{
          concurrency: concurrency,
          poll_interval: poll_interval,
          logger_tag: logger_tag,
          supervisor: supervisor,
          tick_timer: do_schedule_tick(poll_interval),
          max_failure_count: max_failure_count,
        }}

      {:error, reason} ->
        {:stop, {:supervisor, reason}}
    end
  end


  @doc false
  @spec handle_call({atom, QueueState.job_spec_t}, pid, QueueState.t) ::
    {:reply, :ok, QueueState.t}
  def handle_call({:jumbo_enqueue, {job_module, job_args}}, _from, state) do
    {:reply, :ok, do_enqueue_job(job_module, job_args, state)}
  end


  @doc false
  @spec handle_call(:jumbo_get_running_jobs, pid, QueueState.t) ::
    {:reply, :ok, QueueState.t}
  def handle_call(:jumbo_get_running_jobs, _from, %QueueState{running_jobs: running_jobs} = state) do
    {:reply, {:ok, running_jobs |> RunningJobsRegistry.get_jobs()}, state}
  end


  @doc false
  @spec handle_call(:jumbo_get_failed_jobs, pid, QueueState.t) ::
    {:reply, :ok, QueueState.t}
  def handle_call(:jumbo_get_failed_jobs, _from, %QueueState{failed_jobs: failed_jobs} = state) do
    {:reply, {:ok, failed_jobs |> FailedJobsRegistry.get_jobs()}, state}
  end


  @doc false
  @spec handle_call(:jumbo_get_pending_jobs, pid, QueueState.t) ::
    {:reply, :ok, QueueState.t}
  def handle_call(:jumbo_get_pending_jobs, _from, %QueueState{pending_jobs: pending_jobs} = state) do
    {:reply, {:ok, pending_jobs |> PendingJobsRegistry.get_jobs()}, state}
  end



  # Callback received when we received a tick.
  # Checks if there are no failed jobs that should be re-enqueued.
  @doc false
  def handle_info(:jumbo_tick, %QueueState{failed_jobs: failed_jobs, poll_interval: poll_interval, logger_tag: logger_tag} = state) do
    debug(logger_tag, "Tick")

    # FIXME pop many if they are present
    case failed_jobs |> FailedJobsRegistry.pop_many() do
      {:ok, {[], _failed_jobs}} ->
        debug(logger_tag, "No failed jobs popped")
        {:noreply, %{state | tick_timer: do_schedule_tick(poll_interval)}}

      {:ok, {failed_jobs, new_failed_jobs}} ->
        debug(logger_tag, "Failed jobs popped: #{inspect(failed_jobs)}")

        new_state = failed_jobs
          |> Enum.reduce(state, fn(failed_job, acc_state) ->
            do_enqueue_job(failed_job, %{acc_state | failed_jobs: new_failed_jobs})
          end)

        {:noreply, %{new_state | tick_timer: do_schedule_tick(poll_interval)}}
    end
  end


  # Callback received when running job has done its task.
  # We do not do cleanup here as there will be another message such as
  # `{:DOWN, job_ref, :process, _job_pid, :normal}` sent.
  @doc false
  def handle_info({job_ref, :ok}, %QueueState{running_jobs: running_jobs, logger_tag: logger_tag} = state) do
    %RunningJob{id: id, pid: job_pid} = running_jobs |> RunningJobsRegistry.get_by_ref(job_ref)
    debug(logger_tag, "Job #{id} #{inspect(job_pid)}: OK")

    {:noreply, state}
  end


  # Callback received when running job has exited gracefully.
  @doc false
  def handle_info({:DOWN, job_ref, :process, _job_pid, :normal}, %QueueState{running_jobs: running_jobs, logger_tag: logger_tag} = state) do
    %RunningJob{id: id, pid: job_pid} = running_jobs |> RunningJobsRegistry.get_by_ref(job_ref)
    info(logger_tag, "Job #{id} #{inspect(job_pid)}: Process stopped gracefully")

    {:noreply, do_cleanup_job(job_ref, state)}
  end


  # Callback received when process that was running job was killed.
  @doc false
  def handle_info({:DOWN, job_ref, :process, _job_pid, :killed}, %QueueState{running_jobs: running_jobs, logger_tag: logger_tag} = state) do
    %RunningJob{id: id, pid: job_pid} = running_jobs |> RunningJobsRegistry.get_by_ref(job_ref)
    warn(logger_tag, "Job #{id} #{inspect(job_pid)}: Process has been killed")

    {:noreply, do_fail_job(job_ref, :killed, nil, nil, state)}
  end


  # Callback received when running job has thrown something.
  @doc false
  def handle_info({:DOWN, job_ref, :process, _job_pid, {{:nocatch, caught}, stacktrace}}, %QueueState{running_jobs: running_jobs, logger_tag: logger_tag} = state) do
    %RunningJob{id: id, pid: job_pid} = running_jobs |> RunningJobsRegistry.get_by_ref(job_ref)
    warn(logger_tag, "Job #{id} #{inspect(job_pid)}: Thrown #{inspect(caught)} (#{inspect(stacktrace)})")

    {:noreply, do_fail_job(job_ref, :throw, caught, stacktrace, state)}
  end


  # Callback received when running job has raised an exception.
  @doc false
  def handle_info({:DOWN, job_ref, :process, _job_pid, {exception, stacktrace}}, %QueueState{running_jobs: running_jobs, logger_tag: logger_tag} = state) do
    %RunningJob{id: id, pid: job_pid} = running_jobs |> RunningJobsRegistry.get_by_ref(job_ref)
    warn(logger_tag, "Job #{id} #{inspect(job_pid)}: Raised #{inspect(exception)} (#{inspect(stacktrace)})")

    {:noreply, do_fail_job(job_ref, :raise, exception, stacktrace, state)}
  end


  # Enqueues given job. It will run it immediately in a separate process,
  # if there's a free slot, or move it to the pending queue, from which it may
  # be later retreived via `do_next_job/1`.
  defp do_enqueue_job(%FailedJob{id: job_id, module: job_module, args: job_args, failure_count: failure_count}, %QueueState{logger_tag: logger_tag} = state) do
    info(logger_tag, "Re-enqueueuing failed job #{job_id}: #{job_module} (#{inspect(job_args)})")
    do_enqueue_job(job_id, job_module, job_args, failure_count, state)
  end

  defp do_enqueue_job(%PendingJob{id: job_id, module: job_module, args: job_args, failure_count: failure_count}, %QueueState{logger_tag: logger_tag} = state) do
    info(logger_tag, "Re-enqueueuing pending job #{job_id}: #{job_module} (#{inspect(job_args)})")
    do_enqueue_job(job_id, job_module, job_args, failure_count, state)
  end

  defp do_enqueue_job(job_module, job_args, %QueueState{running_jobs: running_jobs, pending_jobs: pending_jobs, failed_jobs: failed_jobs, logger_tag: logger_tag} = state) do
    job_id = JobRegistry.find_unused_job_id([running_jobs, pending_jobs, failed_jobs])
    info(logger_tag, "Enqueueuing new job #{job_id}: #{job_module} (#{inspect(job_args)})")
    do_enqueue_job(job_id, job_module, job_args, 0, state)
  end

  defp do_enqueue_job(job_id, job_module, job_args, job_failure_count, %QueueState{supervisor: supervisor, concurrency: concurrency, running_jobs: running_jobs, pending_jobs: pending_jobs, logger_tag: logger_tag} = state) do
    cond do
      running_jobs |> RunningJobsRegistry.count < concurrency ->
        info(logger_tag, "Starting job #{job_id}: #{job_module} (#{inspect(job_args)})")

        %Task{ref: job_ref, pid: job_pid} = Task.Supervisor.async_nolink(supervisor, fn ->
          Logger.info("[#{job_module} #{inspect(self())}] Job #{job_id}: Start")
          Kernel.apply(job_module, :perform, job_args)
          Logger.info("[#{job_module} #{inspect(self())}] Job #{job_id}: Stop")
        end)

        info(logger_tag, "Started job #{job_id}: #{job_module} (#{inspect(job_args)}) as #{inspect(job_pid)}")
        %{state | running_jobs: running_jobs |> RunningJobsRegistry.put(job_id, job_ref, job_pid, job_module, job_args, job_failure_count)}

      true ->
        info(logger_tag, "Enqueued job #{job_id}: #{job_module} (#{inspect(job_args)})")
        %{state | pending_jobs: pending_jobs |> PendingJobsRegistry.put(job_id, job_module, job_args)}
    end
  end


  # Cleans up given job after it has succeeded. It removes the job from the
  # running queue and checks whether there's no job pending via `do_next_job/1`.
  defp do_cleanup_job(job_ref, %QueueState{running_jobs: running_jobs, logger_tag: logger_tag} = state) do
    %RunningJob{id: id, pid: job_pid, module: job_module, args: job_args} =
      running_jobs
      |> RunningJobsRegistry.get_by_ref(job_ref)

    info(logger_tag, "Cleaning up job #{id} that was running as #{inspect(job_pid)}: #{job_module} (#{inspect(job_args)})")

    %{state |
      running_jobs: running_jobs |> RunningJobsRegistry.delete_by_ref(job_ref)
    } |> do_next_job()
  end


  # Marks given job as failed. It removes the job from the running queue and
  # increases its failure count. If max failure count is reached the job is
  # removed, otherwise it is put into the failed queue from which it may be
  # retreived later (after waiting for some time) due to a tick or
  # via `do_next_job/1`.
  defp do_fail_job(job_ref, reason, info, stacktrace, %QueueState{running_jobs: running_jobs, failed_jobs: failed_jobs, logger_tag: logger_tag, max_failure_count: max_failure_count} = state) do
    %RunningJob{id: id, pid: job_pid, module: job_module, args: job_args, failure_count: failure_count} =
      running_jobs
      |> RunningJobsRegistry.get_by_ref(job_ref)

    new_failure_count = failure_count + 1

    warn(logger_tag, "Failing job #{id} that was running as #{inspect(job_pid)}, failure #{new_failure_count}/#{max_failure_count}: #{job_module} (#{inspect(job_args)})")

    cond do
      new_failure_count < max_failure_count ->
        %{state |
          running_jobs: running_jobs |> RunningJobsRegistry.delete_by_ref(job_ref),
          failed_jobs: failed_jobs |> FailedJobsRegistry.put(id, job_module, job_args, reason, info, stacktrace, new_failure_count),
        } |> do_next_job()

      true ->
        warn(logger_tag, "Removing job #{id} that was running as #{inspect(job_pid)} due to too many failures (#{max_failure_count}): #{job_module} (#{inspect(job_args)})")
        %{state |
          running_jobs: running_jobs |> RunningJobsRegistry.delete_by_ref(job_ref)
        } |> do_next_job()
    end
  end

  # Launched when there's a free slot appearing in the queue, due to succeeded
  # or failed job. It will try to find exactly one pending job that is waiting
  # for execution and enqueue it, then try to do the same with the failed job.
  defp do_next_job(%QueueState{pending_jobs: pending_jobs, failed_jobs: failed_jobs, logger_tag: logger_tag} = state) do
    case pending_jobs |> PendingJobsRegistry.pop() do
      {:ok, {nil, _pending_jobs}} ->
        debug(logger_tag, "No pending jobs popped")

        case failed_jobs |> FailedJobsRegistry.pop() do
          {:ok, {nil, _failed_jobs}} ->
            debug(logger_tag, "No failed jobs popped")
            state

          {:ok, {failed_job, new_failed_jobs}} ->
            debug(logger_tag, "Failed job popped: #{inspect(failed_job)}")
            do_enqueue_job(failed_job, %{state | failed_jobs: new_failed_jobs})
        end

      {:ok, {pending_job, new_pending_jobs}} ->
        debug(logger_tag, "Pending job popped: #{inspect(pending_job)}")
        do_enqueue_job(pending_job, %{state | pending_jobs: new_pending_jobs})
    end
  end


  defp do_schedule_tick(poll_interval) do
    Process.send_after(self(), :jumbo_tick, poll_interval)
  end


  defp info(nil, msg) do
    Logger.info("[#{__MODULE__} #{inspect(self())}] #{msg}")
  end

  defp info(logger_tag, msg) do
    Logger.info("[#{__MODULE__} #{inspect(self())} #{logger_tag}] #{msg}")
  end


  defp debug(nil, msg) do
    Logger.debug("[#{__MODULE__} #{inspect(self())}] #{msg}")
  end

  defp debug(logger_tag, msg) do
    Logger.debug("[#{__MODULE__} #{inspect(self())} #{logger_tag}] #{msg}")
  end


  defp warn(nil, msg) do
    Logger.warn("[#{__MODULE__} #{inspect(self())}] #{msg}")
  end

  defp warn(logger_tag, msg) do
    Logger.warn("[#{__MODULE__} #{inspect(self())} #{logger_tag}] #{msg}")
  end
end
