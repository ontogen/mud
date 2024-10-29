defmodule TestReferencable do
  @moduledoc """
  Test referencable.
  """

  use Grax.Schema
  use Mud.Referencable

  alias Mud.TestNamespaces.EX
  @compile {:no_warn_undefined, Mud.TestNamespaces.EX}

  schema EX.TestReferencable do
    property foo: EX.foo()
  end
end
