defmodule Mud.ProcessorTest do
  use MudCase

  doctest Mud.Processor

  alias Mud.{Processor, Referencable}

  alias RDF.Description

  alias Uniq.UUID

  test "resolves blank node descriptions with mud:ref" do
    prefixes = RDF.turtle_prefixes(ex: EX, mud: Mud, void: "http://rdfs.org/ns/void#")
    ref = "foo"
    salt_file_path = Referencable.Id.salt_path(ref)

    refute File.exists?(salt_file_path)

    graph =
      """
      #{prefixes}

      [
        a ex:TestReferencable
        ; mud:ref "#{ref}"
        ; void:triples 42
      ].
      """
      |> Turtle.read_string!()

    assert {:ok, %Graph{} = processed_graph} = Processor.process(graph)

    assert File.exists?(salt_file_path)
    salt = File.read!(salt_file_path)

    assert [processed_description] = Graph.descriptions(processed_graph)

    assert [%Literal{literal: %XSD.String{value: hash}}] =
             processed_description[Mud.refHash()]

    assert hash == hkdf_hash(salt)

    assert %IRI{value: "urn:uuid:" <> uuid} = processed_description.subject
    assert uuid == UUID.uuid5(Mud.IdSpec.mud_uuid_namespace(), hash)

    assert processed_graph ==
             """
             #{prefixes}

             <urn:uuid:#{uuid}> a ex:TestReferencable
               ; mud:ref "#{ref}"
               ; mud:refHash "#{hash}"
               ; void:triples 42
             .
             """
             |> Turtle.read_string!()

    assert {:ok, ^processed_graph} = Processor.process(graph)
    assert {:ok, ^processed_graph} = Processor.process(graph)
  end

  test "resolves referencable object blank node description" do
    prefixes =
      RDF.turtle_prefixes(
        mud: Mud,
        ex: EX,
        foaf: FOAF
      )

    graph =
      """
      #{prefixes}

      [
        a ex:TestReferencable
        ; mud:ref "foo"
        ; foaf:maker [ a foaf:Agent
            ; mud:ref "user"
            ; foaf:name "John Doe"
          ]
      ].

      [
        a foaf:Agent
        ; mud:ref "user"
        ; foaf:firstName "John"
        ; foaf:lastName "Doe"
      ].
      """
      |> Turtle.read_string!()

    assert {:ok, %Graph{} = graph} = Processor.process(graph)

    ref_indexed_graph = ref_indexed(graph)
    foo_id = ref_indexed_graph[:foo].subject
    user_id = ref_indexed_graph[:user].subject
    foo_hash = Mud.refHash(ref_indexed_graph[:foo])
    user_hash = Mud.refHash(ref_indexed_graph[:user])

    assert ref_indexed_graph == %{
             foo:
               foo_id
               |> RDF.type(EX.TestReferencable)
               |> Mud.ref("foo")
               |> Mud.refHash(foo_hash)
               |> FOAF.maker(user_id),
             user:
               user_id
               |> RDF.type(FOAF.Agent)
               |> Mud.ref("user")
               |> Mud.refHash(user_hash)
               |> FOAF.name("John Doe")
               |> FOAF.firstName("John")
               |> FOAF.lastName("Doe")
           }
  end

  test "maintains reference relationships" do
    graph =
      """
      #{RDF.turtle_prefixes(ex: EX, mud: Mud)}

      _:ref1 a ex:TestReferencable ;
             ex:label "1" ;
             mud:ref "test1" .

      _:ref2 a ex:TestReferencable ;
             ex:label "2" ;
             mud:ref "test2" ;
             ex:relatedTo _:ref1 .
      """
      |> Turtle.read_string!()

    {:ok, processed} = Processor.process(graph)

    [%{s1: s1, s2: s2}] = Graph.query(processed, {:s2?, EX.relatedTo(), :s1?})
    assert processed[s1][EX.label()] == [~L"1"]
    assert processed[s2][EX.label()] == [~L"2"]
  end

  test "resolves mud:this" do
    prefixes =
      RDF.turtle_prefixes(
        mud: Mud,
        ex: EX,
        foaf: FOAF
      )

    assert """
           #{prefixes}

           [
             mud:this ex:TestReferencable
             ; foaf:maker [ mud:this foaf:Agent
                 ; foaf:name "John Doe"
               ]
           ].

           [
             mud:this foaf:Agent
             ; foaf:firstName "John"
             ; foaf:lastName "Doe"
           ].
           """
           |> Turtle.read_string!()
           |> Processor.process() ==
             """
             #{prefixes}

             [
               a ex:TestReferencable
               ; mud:ref "testReferencable"
               ; foaf:maker [ a foaf:Agent
                   ; mud:ref "agent"
                   ; foaf:name "John Doe"
                 ]
             ].

             [
               a foaf:Agent
               ; mud:ref "agent"
               ; foaf:firstName "John"
               ; foaf:lastName "Doe"
             ].
             """
             |> Turtle.read_string!()
             |> Processor.process()
  end

  test "resolves mud:I" do
    prefixes =
      RDF.turtle_prefixes(
        mud: Mud,
        ex: EX,
        foaf: FOAF
      )

    assert """
           #{prefixes}

           mud:I
               foaf:firstName "John"
             ; foaf:lastName "Doe"
           .
           """
           |> Turtle.read_string!()
           |> Processor.process() ==
             """
             #{prefixes}

             [
               a foaf:Agent
               ; mud:ref "agent"
               ; foaf:firstName "John"
               ; foaf:lastName "Doe"
             ].
             """
             |> Turtle.read_string!()
             |> Processor.process()

    assert """
           #{prefixes}

           [
             a ex:TestReferencable
             ; mud:ref "testReferencable"
             ; foaf:maker mud:I
           ] .

           mud:I
               foaf:firstName "John"
             ; foaf:lastName "Doe"
           .
           """
           |> Turtle.read_string!()
           |> Processor.process() ==
             """
             #{prefixes}

             [
               a ex:TestReferencable
               ; mud:ref "testReferencable"
               ; foaf:maker [ a foaf:Agent
                   ; mud:ref "agent"
                 ]
             ].

             [
               a foaf:Agent
               ; mud:ref "agent"
               ; foaf:firstName "John"
               ; foaf:lastName "Doe"
             ].
             """
             |> Turtle.read_string!()
             |> Processor.process()
  end

  test "with non-referencable blank nodes" do
    prefixes = RDF.turtle_prefixes(ex: EX)

    graph =
      """
      #{prefixes}

      [
        a ex:TestReferencable
        ; ex:foo 42
      ].
      """
      |> Turtle.read_string!()

    assert {:ok, ^graph} = Processor.process(graph)
  end

  test "when multiple refs for the same subject are defined" do
    graph =
      """
      #{RDF.turtle_prefixes(ex: EX, mud: Mud)}

      [
        a ex:TestReferencable
        ; mud:ref "foo", "bar"
      ].
      """
      |> Turtle.read_string!()

    assert {:error, %Grax.ValidationError{errors: [__ref__: _]}} =
             Processor.process(graph)
  end

  test "ignores non-referencable blank nodes" do
    graph =
      """
      #{RDF.turtle_prefixes(ex: EX, mud: Mud)}

      _:ref1 a ex:TestClass ;
             ex:value [ ex:something "value" ] .
      """
      |> Turtle.read_string!()

    assert {:ok, ^graph} = Processor.process(graph)
  end

  defp ref_indexed(%Graph{} = graph), do: graph |> Graph.descriptions() |> ref_indexed()

  defp ref_indexed(descriptions) do
    Enum.reduce(descriptions, %{}, fn description, ref_index ->
      if ref = Description.first(description, Mud.ref()) do
        Map.put(ref_index, ref |> to_string() |> String.to_atom(), description)
      else
        Map.put(ref_index, nil, description)
      end
    end)
  end

  defp hkdf_hash(salt) do
    :sha256
    |> HKDF.derive(String.trim_trailing("salt: #{salt}"), 16)
    |> Base.encode16(case: :lower)
  end
end
