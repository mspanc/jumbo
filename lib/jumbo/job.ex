defmodule Jumbo.Job do
  @moduledoc """
  Module containing common code for all job types.
  """

  @type module_t :: module
  @type args_t   :: list
  @type spec_t   :: {module_t, args_t}
end
