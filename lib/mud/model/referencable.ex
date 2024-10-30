defmodule Mud.Referencable do
  use Grax.Schema

  alias RDF.{Graph, IRI}
  alias Mud.NotMinted
  alias Mud.Referencable.Id

  import Mud.Utils, only: [bang!: 2]

  schema Mud.Referencable do
    # This field is for local use only, it MUST NOT be stored or hashed!
    property __ref__: Mud.ref(), type: :string, required: true

    # the value used as the UUIDv5 name of the root namespace (see id_spec.ex)
    property __hash__: Mud.refHash(),
             type: :string,
             required: true
  end

  @type ref :: String.t()

  @callback deref(ref(), Graph.t()) :: {:ok, Grax.Schema.t()} | {:error, any}

  @callback this_ref :: ref()

  @callback this_id :: {:ok, RDF.IRI.t()} | {:error, any}

  @callback this(Graph.t()) :: {:ok, Grax.Schema.t()} | {:error, any}

  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)

      @impl true
      def deref(ref, graph, opts \\ [])

      def deref(:this, graph, opts), do: deref({:this, __MODULE__}, graph, opts)

      def deref(ref, graph, opts) do
        with {:ok, id} <- unquote(__MODULE__).deref_id(ref) do
          load(graph, id, Keyword.put_new(opts, :depth, 99))
        end
      end

      def deref!(ref, graph, opts \\ []) do
        case deref(ref, graph, opts) do
          {:ok, schema} -> schema
          {:error, %NotMinted{}} -> nil
          {:error, error} -> raise error
        end
      end

      @impl true
      def this(graph, opts \\ []), do: deref(:this, graph, opts)
      def this!(graph, opts \\ []), do: deref!(:this, graph, opts)

      @impl true
      def this_id, do: unquote(__MODULE__).deref_id({:this, __MODULE__})
      def this_id!, do: unquote(__MODULE__).deref_id!({:this, __MODULE__})

      @impl true
      def this_ref, do: unquote(__MODULE__).this_ref(__MODULE__)
    end
  end

  def new(ref, opts \\ [])

  def new({:this, schema}, opts), do: schema |> this_ref() |> new(opts)

  def new(ref, opts) when is_binary(ref) do
    %__MODULE__{__ref__: ref}
    |> Id.generate(opts)
  end

  def new!(ref, opts \\ []), do: bang!(&new/2, [ref, opts])

  def mint(ref), do: new(ref, mint: true)
  def mint!(ref), do: bang!(&mint/1, [ref])

  def load_from_rdf(graph, id, opts \\ []) do
    with {:ok, referencable} <- load(graph, id, Keyword.put(opts, :validate, false)) do
      validate(referencable, minted: false)
    end
  end

  def load_from_rdf!(graph, id, opts \\ []), do: bang!(&load_from_rdf/3, [graph, id, opts])

  def validate(%__MODULE__{} = referencable, opts \\ []) do
    {minted, opts} = Keyword.pop(opts, :minted)

    if minted do
      Grax.validate(referencable, opts)
    else
      with {:ok, _} <- %{referencable | __hash__: "unminted"} |> Grax.validate(opts) do
        {:ok, referencable}
      end
    end
  end

  @doc """
  Returns the IRI of a referenced resource.
  """
  def deref_id(ref)

  def deref_id({:this, schema}), do: schema |> this_ref() |> deref_id()

  def deref_id(ref) do
    with {:ok, referencable} <- new(ref) do
      {:ok, referencable.__id__}
    end
  end

  def deref_id!(ref) do
    case deref_id(ref) do
      {:ok, id} -> id
      {:error, %NotMinted{}} -> nil
      {:error, error} -> raise error
    end
  end

  @doc """
  Returns the ref name for the referencable singleton instance of the given schema or class IRI.

  ### Examples

      iex> Mud.Referencable.this_ref(~I<http://xmlns.com/foaf/0.1/Agent>)
      "agent"

      iex> Mud.Referencable.this_ref(FOAF.Agent)
      "agent"
  """
  def this_ref(%IRI{} = class) do
    case IRI.parse(class) do
      %URI{fragment: nil, path: path} -> Path.basename(path)
      %URI{fragment: fragment} -> fragment
    end
    |> String.split_at(1)
    |> case do
      {first_letter, rest} ->
        downcased = String.downcase(first_letter)

        if first_letter == downcased do
          raise "invalid class URI #{class}; must start with a uppercase letter"
        else
          downcased <> rest
        end
    end
  end

  def this_ref(schema), do: schema.__class__() |> RDF.iri() |> this_ref()

  def on_to_rdf(%{__id__: id}, graph, _opts) do
    {
      :ok,
      graph
      |> Graph.delete({id, RDF.type(), Mud.Referencable})
    }
  end

  @doc """
  Checks if the given `module` is a `Mud.Referencable`.
  """
  @spec type?(module) :: boolean
  def type?(module) when is_atom(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :deref, 2)
  end

  def type?(%IRI{} = iri), do: iri |> Grax.schema() |> type?()
  def type?(_), do: false
end
