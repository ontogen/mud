defmodule Mud.IdSpec do
  @moduledoc false

  use Grax.Id.Spec

  alias Uniq.UUID

  import Grax.Id.UUID

  @root_namespace "a5270087-9bf3-4714-8419-ab49319ef945"
  def root_namespace, do: @root_namespace

  @mud_uuid_namespace "935723a1-265b-59bc-ab47-41f48fba11d7" =
                        UUID.uuid5(@root_namespace, "mud")

  def mud_uuid_namespace, do: @mud_uuid_namespace

  urn :uuid do
    uuid5 Mud.Referencable.__hash__(), namespace: @mud_uuid_namespace
  end
end
