defmodule Mud.Referencable.IdTest do
  use MudCase

  doctest Mud.Referencable.Id

  alias Mud.{Referencable, NotMinted, AlreadyMinted}
  alias Mud.Referencable.Id

  test "generates deterministic URIs" do
    ref = %Referencable{__ref__: "test", __class__: EX.TestClass}

    {:ok, result1} = Id.generate(ref, mint: true)
    {:ok, result2} = Id.generate(ref)

    assert result1.__id__ == result2.__id__
    assert String.starts_with?(result1.__id__.value, "urn:uuid:")
  end

  test "generates different URIs for different references" do
    ref1 = %Referencable{__ref__: "test1", __class__: EX.TestClass}
    ref2 = %Referencable{__ref__: "test2", __class__: EX.TestClass}

    {:ok, result1} = Id.generate(ref1, mint: true)
    {:ok, result2} = Id.generate(ref2, mint: true)

    refute result1.__id__ == result2.__id__
  end

  test "requires minting for first access" do
    ref = %Referencable{__ref__: "test", __class__: EX.TestClass}

    assert {:error, %NotMinted{}} = Id.generate(ref)
    assert {:ok, result} = Id.generate(ref, mint: true)
    assert {:ok, ^result} = Id.generate(ref)
  end
end
