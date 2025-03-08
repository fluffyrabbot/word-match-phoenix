defmodule Nostrum.Struct.Message do
  @moduledoc """
  Mock Nostrum Message struct for testing.
  """
  defstruct [:id, :guild_id, :author, :channel_id, :content, :timestamp]
end

defmodule Nostrum.Struct.Interaction do
  @moduledoc """
  Mock Nostrum Interaction struct for testing.
  """
  defstruct [
    :id, :guild_id, :user, :data, :token, :version, :application_id,
    :channel, :channel_id, :guild_locale, :locale, :member, :message, :type
  ]
end
