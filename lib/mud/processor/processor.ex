defmodule Mud.Processor do
  use RDF
  alias RDF.{Graph, Description, BlankNode}
  alias Mud.Referencable

  @spec process(Graph.t(), keyword) :: {:ok, Graph.t()} | {:error, any}
  def process(%Graph{} = graph, opts \\ []) do
    graph
    |> resolve_indexicals(opts)
    |> resolve_referencables(opts)
  end

  defp resolve_indexicals(graph, opts) do
    graph
    |> resolve_me_indexical(opts)
    |> resolve_this_indexical(opts)
  end

  defp resolve_me_indexical(graph, _opts) do
    me_bnode = RDF.bnode()

    graph =
      case Graph.pop(graph, Mud.I) do
        {%Description{} = user, graph} ->
          Graph.add(
            graph,
            user
            |> Description.change_subject(me_bnode)
            |> me_as_referencable()
          )

        {nil, graph} ->
          graph
      end

    graph
    |> Graph.query({:s?, :p?, Mud.I})
    |> Enum.reduce(graph, fn %{s: s, p: p}, graph ->
      graph
      |> Graph.delete({s, p, Mud.I})
      |> Graph.add({s, p, me_bnode})
      |> Graph.add(me_as_referencable(me_bnode))
    end)
  end

  defp me_as_referencable(me) do
    me
    |> RDF.type(Mud.i_class())
    |> Mud.ref(Mud.i_ref())
  end

  defp resolve_this_indexical(graph, _opts) do
    graph
    |> Graph.query({:subject?, Mud.this(), :class?})
    |> Enum.reduce(graph, fn %{subject: subject, class: class}, graph ->
      graph
      |> Graph.delete({subject, Mud.this(), class})
      |> Graph.add(subject |> RDF.type(class) |> Mud.ref(Referencable.this_ref(class)))
    end)
  end

  defp resolve_referencables(graph, opts) do
    with {:ok, processed_resources} <-
           graph
           |> Graph.query({:subject?, Mud.ref(), :ref?})
           |> RDF.Utils.map_while_ok(fn %{subject: subject, ref: _ref} ->
             with {:ok, referencable} <- Referencable.load_from_rdf(graph, subject),
                  {:ok, resolved_referencable} <- resolve_referencable(referencable, opts) do
               {:ok, {subject, resolved_referencable}}
             end
           end) do
      with_processed_subjects =
        Enum.reduce(processed_resources, graph, fn
          {resource, resolved_referencable}, processed_graph ->
            processed_graph
            |> Graph.add(Grax.to_rdf!(resolved_referencable, prefixes: []))
            |> Graph.delete_descriptions(resource)
        end)

      processed_graph =
        Enum.reduce(processed_resources, with_processed_subjects, fn
          {resource, resolved_referencable}, processed_graph ->
            rename(processed_graph, resource, resolved_referencable.__id__)
        end)

      {:ok, processed_graph}
    end
  end

  # We don't have to deal with non-referencable blank nodes, because these were filtered out already
  defp resolve_referencable(%Referencable{__id__: %BlankNode{}} = anonymous_referencable, opts) do
    Referencable.Id.generate(anonymous_referencable, Keyword.put(opts, :mint, true))
  end

  defp rename(graph, old_id, new_id) do
    Graph.rename_resource(graph, old_id, new_id)
  end
end
