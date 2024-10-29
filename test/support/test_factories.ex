defmodule Mud.TestFactories do
  @moduledoc """
  Test factories.
  """

  use RDF

  alias RDF.Graph

  alias Mud.TestNamespaces.EX
  @compile {:no_warn_undefined, Mud.TestNamespaces.EX}

  def id(:agent), do: ~I<http://example.com/Agent>
  def id(:agent_john), do: ~I<http://example.com/Agent/john_doe>
  def id(:agent_jane), do: ~I<http://example.com/Agent/jane_doe>
  def id(resource) when is_rdf_resource(resource), do: resource
  def id(iri) when is_binary(iri), do: RDF.iri(iri)

  def email(format \\ :iri)
  def email(:iri), do: ~I<mailto:john.doe@example.com>

  def datetime, do: ~U[2023-05-26 13:02:02.255559Z]

  def datetime(amount_to_add, unit \\ :second),
    do: datetime() |> DateTime.add(amount_to_add, unit)

  def statement(id) when is_integer(id) or is_atom(id) do
    {
      apply(EX, :"s#{id}", []),
      apply(EX, :"p#{id}", []),
      apply(EX, :"o#{id}", [])
    }
  end

  def statement({id1, id2})
      when (is_integer(id1) or is_atom(id1)) and (is_integer(id2) or is_atom(id2)) do
    {
      apply(EX, :"s#{id1}", []),
      apply(EX, :"p#{id2}", []),
      apply(EX, :"o#{id2}", [])
    }
  end

  def statement({id1, id2, id3} = triple)
      when (is_integer(id1) or is_atom(id1)) and
             (is_integer(id2) or is_atom(id2)) and
             (is_integer(id3) or is_atom(id3)) do
    if RDF.Triple.valid?(triple) do
      triple
    else
      {
        apply(EX, :"s#{id1}", []),
        apply(EX, :"p#{id2}", []),
        apply(EX, :"o#{id3}", [])
      }
    end
  end

  def statement(statement), do: statement

  def statements(statements) when is_list(statements) do
    Enum.flat_map(statements, fn
      statement when is_integer(statement) or is_atom(statement) or is_tuple(statement) ->
        [statement(statement)]

      statement ->
        statement |> RDF.graph() |> Graph.statements()
    end)
  end

  def empty_graph, do: RDF.graph()

  @graph [
           EX.S1 |> EX.p1(EX.O1),
           EX.S2 |> EX.p2(42, "Foo")
         ]
         |> RDF.graph()
  def graph, do: @graph

  def graph(statements, opts \\ [])

  def graph(statement, opts) when is_integer(statement) or is_atom(statement) do
    statement |> statement() |> RDF.graph(opts)
  end

  def graph(statements, opts) when is_list(statements) do
    statements |> statements() |> RDF.graph(opts)
  end

  def graph(other, opts) do
    RDF.graph(other, opts)
  end

  @subgraph [
              EX.S1 |> EX.p1(EX.O1)
            ]
            |> RDF.graph()
  def subgraph, do: @subgraph
end
