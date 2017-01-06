defmodule Jumbo.Job do
  @moduledoc false

  @type id_t     :: String.t # will hold UUIDs
  @type module_t :: module
  @type args_t   :: list
  @type spec_t   :: {module_t, args_t}


  @spec new_id() :: id_t
  def new_id() do
    UUID.uuid4()
  end
end
