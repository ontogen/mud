defmodule Mud.Utils do
  @moduledoc false

  def bang!(fun, args) do
    case apply(fun, args) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end
end
