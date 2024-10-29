defmodule MudCase do
  @moduledoc """
  Common `ExUnit.CaseTemplate` for Mud tests.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use RDF
      alias RDF.{IRI, BlankNode, Literal, Graph}
      import RDF, only: [iri: 1, literal: 1, bnode: 1]

      alias Mud

      alias Mud.TestData
      import Mud.TestFactories

      alias Mud.TestNamespaces.EX
      @compile {:no_warn_undefined, Mud.TestNamespaces.EX}

      import unquote(__MODULE__)

      setup :clean_salts!
    end
  end

  def clean_salts!(_context) do
    salt_base_path =
      "tmp/test/data/" <> _ =
      Mud.salt_base_path()

    File.rm_rf!(salt_base_path)

    Mud.create_salt_base_path()

    :ok
  end
end
