defmodule Mud.ReferencableTest do
  use MudCase

  doctest Mud.Referencable

  alias Mud.{Referencable, NotMinted}

  describe "load_from_rdf/2" do
    test "valid referencable" do
      graph =
        """
        #{RDF.turtle_prefixes(ex: EX, mud: Mud)}

        _:example
          a ex:TestReferencable
          ; mud:ref "foo"
          ; ex:foo 42
        .
        """
        |> Turtle.read_string!()

      assert Referencable.load_from_rdf(graph, ~B<example>) ==
               {:ok,
                %Mud.Referencable{
                  __additional_statements__: %{
                    ~I<http://example.com/foo> => %{RDF.XSD.Integer.new(42) => nil},
                    ~I<http://www.w3.org/1999/02/22-rdf-syntax-ns#type> => %{
                      ~I<https://w3id.org/mud#Referencable> => nil,
                      ~I<http://example.com/TestReferencable> => nil
                    }
                  },
                  __id__: ~B<example>,
                  __ref__: "foo",
                  __hash__: nil
                }}
    end

    test "with multiple classes for the same subject are defined" do
      graph =
        """
        #{RDF.turtle_prefixes(ex: EX, mud: Mud, foaf: FOAF)}

        _:example
          a ex:TestReferencable, foaf:Agent, ex:Class
          ; mud:ref "foo"
          ; ex:foo 42
        .
        """
        |> Turtle.read_string!()

      assert Referencable.load_from_rdf(graph, ~B<example>) ==
               {:ok,
                %Mud.Referencable{
                  __additional_statements__: %{
                    ~I<http://example.com/foo> => %{RDF.XSD.Integer.new(42) => nil},
                    ~I<http://www.w3.org/1999/02/22-rdf-syntax-ns#type> => %{
                      ~I<https://w3id.org/mud#Referencable> => nil,
                      ~I<http://example.com/TestReferencable> => nil,
                      RDF.iri(EX.Class) => nil,
                      RDF.iri(FOAF.Agent) => nil
                    }
                  },
                  __id__: ~B<example>,
                  __ref__: "foo",
                  __hash__: nil
                }}
    end

    test "when multiple refs for the same subject are defined" do
      graph =
        """
        #{RDF.turtle_prefixes(ex: EX, mud: Mud)}

        _:example
          a ex:TestReferencable
          ; mud:ref "foo", "bar"
          ; ex:foo 42
        .
        """
        |> Turtle.read_string!()

      assert {:error, %Grax.ValidationError{errors: [__ref__: _]}} =
               Referencable.load_from_rdf(graph, ~B<example>)
    end
  end

  test "new/2" do
    assert {:error, %NotMinted{referencable: %{__ref__: "testReferencable"}}} =
             Referencable.new("testReferencable")

    assert {:ok, %Referencable{__id__: %IRI{value: "urn:uuid:" <> _}} = ref} =
             Referencable.new("testReferencable", mint: true)

    assert {:ok, ^ref} = Referencable.new("testReferencable", mint: true)
    assert {:ok, ^ref} = Referencable.new("testReferencable")
  end

  describe "deref_id/1 and deref_id!/1" do
    test "when the id is not minted" do
      assert {:error, %NotMinted{referencable: %{__ref__: "testReferencable"}}} =
               Referencable.deref_id("testReferencable")

      refute Referencable.deref_id!("testReferencable")
    end

    test "when the id is minted" do
      assert {:ok, ref} = Referencable.mint("testReferencable")

      assert Referencable.deref_id!("testReferencable") == ref.__id__
    end
  end

  describe "deref/1" do
    test "when the id is not minted" do
      assert {:error, %NotMinted{referencable: %{__ref__: "testReferencable"}}} =
               TestReferencable.deref("testReferencable", empty_graph())

      refute TestReferencable.deref!("testReferencable", empty_graph())
    end

    test "when the id is minted, but not described in the graph" do
      assert {:ok, %Referencable{}} = Referencable.mint("testReferencable")

      assert TestReferencable.deref!("testReferencable", empty_graph()) ==
               TestReferencable.build!(Referencable.deref_id!("testReferencable"))
    end

    test "when the id is minted and described in the graph" do
      assert {:ok, %Referencable{}} = Referencable.mint("testReferencable")

      assert (test = TestReferencable.deref!("testReferencable", test_graph())) ==
               TestReferencable.build!(Referencable.deref_id!("testReferencable"),
                 foo: "test"
               )

      assert ^test = TestReferencable.deref!("testReferencable", test_graph())
    end
  end

  describe "this/0" do
    test "when the id is not minted" do
      assert {:error, %NotMinted{referencable: %{__ref__: "testReferencable"}}} =
               TestReferencable.this(empty_graph())

      refute TestReferencable.this!("testReferencable", empty_graph())
    end

    test "when the id is minted" do
      assert {:ok, %Referencable{}} = Referencable.mint("testReferencable")

      assert %TestReferencable{} = test = TestReferencable.this!(test_graph())

      assert TestReferencable.this!(test_graph()) ==
               TestReferencable.deref!("testReferencable", test_graph())

      assert ^test = TestReferencable.this!(test_graph())
    end
  end

  describe "this_id/0" do
    test "when the id is not minted" do
      assert {:error, %NotMinted{referencable: %{__ref__: "testReferencable"}}} =
               TestReferencable.this_id()

      refute TestReferencable.this_id!()
    end

    test "when the id is minted" do
      assert {:ok, %Referencable{}} = Referencable.mint(TestReferencable.this_ref())

      assert {:ok, %IRI{value: "urn:uuid:" <> _} = id} = TestReferencable.this_id()
      assert ^id = TestReferencable.this_id!()
      assert TestReferencable.this_id!() == Referencable.deref_id!("testReferencable")
    end
  end

  test "this_ref/0" do
    assert TestReferencable.this_ref() == "testReferencable"
  end

  test "this_ref/1" do
    assert Referencable.this_ref(~I<https://example.com/random#Thing>) == "thing"
    assert Referencable.this_ref(EX.Thing) == "thing"
    assert Referencable.this_ref(FOAF.Agent) == "agent"

    assert_raise RuntimeError, fn ->
      Referencable.this_ref(~I<https://example.com/random#>)
    end

    assert_raise RuntimeError, fn ->
      Referencable.this_ref(~I<https://example.com/>)
    end

    assert_raise RuntimeError, fn ->
      Referencable.this_ref(FOAF.mbox())
    end
  end

  describe "type?/1" do
    test "with a module" do
      assert Mud.Referencable.type?(TestReferencable)
      refute Mud.Referencable.type?(FOAF.Agent)
      refute Mud.Referencable.type?(NotExisting)
    end

    test "with an IRI" do
      assert EX.TestReferencable |> RDF.iri() |> Mud.Referencable.type?()
      refute FOAF.Agent |> RDF.iri() |> Mud.Referencable.type?()
      refute EX.Foo |> RDF.iri() |> Mud.Referencable.type?()
    end
  end

  def test_graph do
    (TestReferencable.this_id!() || raise("TestReferencable not minted yet"))
    |> EX.foo("test")
    |> RDF.graph()
  end
end
