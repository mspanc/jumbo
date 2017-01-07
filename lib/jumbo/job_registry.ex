defmodule Jumbo.JobRegistry do
  @moduledoc false

  alias Jumbo.JobId


  @callback get_ids(struct) :: MapSet.t


  @doc """
  Finds first unused ID for given registries.

  In case of collision works recursively until unused ID is found.

  Always returns String.
  """
  @spec find_unused_job_id([struct]) :: JobId.t
  def find_unused_job_id(registries) do
    new_id = JobId.new()

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
