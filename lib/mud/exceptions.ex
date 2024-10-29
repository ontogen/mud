defmodule Mud.NotMinted do
  @moduledoc """
  Raised when the salt file for a referencable is not present.
  """
  defexception [:referencable]

  alias Mud.Referencable

  def message(%{referencable: referencable}) do
    "No salt file #{Referencable.Id.salt_path(referencable)} found for #{inspect(referencable)}"
  end
end

defmodule Mud.AlreadyMinted do
  @moduledoc """
  Raised when the salt file for a referencable is not present.
  """
  defexception [:referencable]

  alias Mud.Referencable

  def message(%{referencable: referencable}) do
    "Salt file #{Referencable.Id.salt_path(referencable)} for #{inspect(referencable)} already exits"
  end
end
