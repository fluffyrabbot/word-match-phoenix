defmodule Nostrum.Struct.Message do
  @moduledoc """
  Mock Nostrum Message struct for testing.
  """
  defstruct [
    :id, :guild_id, :author, :channel_id, :content, :timestamp, :mentions, :type,
    :activity, :application, :application_id, :attachments, :components,
    :edited_timestamp, :embeds, :interaction, :member, :mention_channels,
    :mention_everyone, :mention_roles, :message_reference, :nonce, :pinned,
    :poll, :reactions, :referenced_message, :sticker_items, :thread,
    :tts, :webhook_id
  ]
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
