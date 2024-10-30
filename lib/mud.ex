defmodule Mud do
  import RDF.Namespace
  import Mud.Utils, only: [bang!: 2]

  act_as_namespace Mud.NS.Mud

  @default_i_class RDF.iri(FOAF.Agent)
  def i_class do
    Application.get_env(:mud, :i_class, @default_i_class)
  end

  def i_ref do
    Application.get_env(:mud, :i_ref, Mud.Referencable.this_ref(i_class()))
  end

  @default_salt_base_path ".mud/.ref_salts/"

  def salt_base_path do
    Application.get_env(:mud, :salt_path, @default_salt_base_path)
  end

  def create_salt_base_path do
    base_salt_path = salt_base_path()
    unless File.exists?(base_salt_path), do: File.mkdir_p!(base_salt_path)
    base_salt_path
  end

  defdelegate precompile(graph, opts \\ []), to: Mud.Precompiler

  def precompile!(graph, opts \\ []), do: bang!(&precompile/2, [graph, opts])
end
