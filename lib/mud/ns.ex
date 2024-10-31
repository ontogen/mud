defmodule Mud.NS do
  @moduledoc """
  `RDF.Vocabulary.Namespace`s for the used vocabularies within Mud.
  """

  use RDF.Vocabulary.Namespace

  @vocabdoc """
  The vocabulary for the Mud language.

  See <https://w3id.org/mud/spec>
  """
  defvocab Mud,
    base_iri: "https://w3id.org/mud#",
    file: "mud.ttl",
    case_violations: :fail

  @prefixes RDF.prefix_map(
              mud: Mud,
              foaf: FOAF
            )

  def prefixes, do: @prefixes

  def prefixes(filter), do: RDF.PrefixMap.limit(@prefixes, filter)
end
