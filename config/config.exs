import Config

config :logger, level: :warning

config :mud,
  grax_id_spec: Mud.IdSpec

import_config "#{Mix.env()}.exs"
