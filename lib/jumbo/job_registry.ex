defmodule Jumbo.JobRegistry do
  @moduledoc false

  alias Jumbo.Job


  @callback get_ids(struct) :: MapSet.t


  @doc """
  Finds first unused ID for given registries.

  In case of collision works recursively until unused ID is found.

  Always returns String.
  """
  @spec find_unused_job_id([struct]) :: Job.id_t
  def find_unused_job_id(registries) do
    new_id = Job.new_id()

    case Enum.any?(registries, fn(registry) ->
      registry |> registry.__struct__.get_ids() |> MapSet.member?(new_id) 
    end) do
      true ->
        find_unused_job_id(registries)

      false ->
        new_id
    end
  end
end
