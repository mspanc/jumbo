defmodule Jumbo.Job do
  @moduledoc """
  Module containing common functions for all job types.
  """

  @type id_t     :: << _ :: 16 >> # will hold UUIDv4
  @type module_t :: module
  @type args_t   :: list
  @type spec_t   :: {module_t, args_t}


  @doc """
  Generates new random job identifier.

  It will return a 16-bytes long bitstring that is conforming with UUIDv4.
  """
  @spec new_id() :: id_t
  def new_id() do
    <<u0::48, _::4, u1::12, _::2, u2::62>> = :crypto.strong_rand_bytes(16)
    <<u0::48, 4::4, u1::12, 2::2, u2::62>>
  end


  @doc """
  Converts given job identifier to printable UUIDv4 string.
  """
  @spec id_to_string(id_t) :: String.t
  def id_to_string(<<u0::32, u1::16, u2::16, u3::16, u4::48>>) do
    [binary_to_hex_list(<<u0::32>>), ?-, binary_to_hex_list(<<u1::16>>), ?-,
     binary_to_hex_list(<<u2::16>>), ?-, binary_to_hex_list(<<u3::16>>), ?-,
     binary_to_hex_list(<<u4::48>>)]
    |> IO.iodata_to_binary
  end


  defp binary_to_hex_list(binary) do
    :binary.bin_to_list(binary)
      |> list_to_hex_str
  end


  defp list_to_hex_str([]) do
    []
  end

  defp list_to_hex_str([head | tail]) do
    to_hex_str(head) ++ list_to_hex_str(tail)
  end


  defp to_hex_str(n) when n < 256 do
    [to_hex(div(n, 16)), to_hex(rem(n, 16))]
  end


  defp to_hex(i) when i < 10 do
    0 + i + 48
  end

  defp to_hex(i) when i >= 10 and i < 16 do
    ?a + (i - 10)
  end
end
