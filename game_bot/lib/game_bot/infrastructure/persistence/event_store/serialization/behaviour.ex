defmodule GameBot.Infrastructure.Persistence.EventStore.Serialization.Behaviour do
  @moduledoc """
  Defines the behaviour for event serialization and deserialization.

  This module provides the contract for serializing domain events to a format
  suitable for storage and deserializing them back into domain events.

  Key features:
  - Version-aware serialization
  - Error handling
  - Type validation
  - Metadata preservation
  """

  alias GameBot.Infrastructure.Error

  @type event :: struct()
  @type version :: pos_integer()
  @type serialized :: map()
  @type metadata :: map()

  @doc """
  Serializes a domain event into a format suitable for storage.

  ## Parameters
    * `event` - The domain event to serialize
    * `opts` - Optional serialization options

  ## Returns
    * `{:ok, serialized}` - Successfully serialized event
    * `{:error, Error.t()}` - Error during serialization
  """
  @callback serialize(event(), keyword()) ::
    {:ok, serialized()} | {:error, Error.t()}

  @doc """
  Deserializes stored data back into a domain event.

  ## Parameters
    * `data` - The serialized event data
    * `opts` - Optional deserialization options

  ## Returns
    * `{:ok, event}` - Successfully deserialized event
    * `{:error, Error.t()}` - Error during deserialization
  """
  @callback deserialize(serialized(), keyword()) ::
    {:ok, event()} | {:error, Error.t()}

  @doc """
  Returns the version of the serialization format.

  ## Returns
    * `version` - The current version number
  """
  @callback version() :: version()

  @doc """
  Validates that the serialized data matches the expected format.

  ## Parameters
    * `data` - The serialized event data to validate
    * `opts` - Optional validation options

  ## Returns
    * `:ok` - Data is valid
    * `{:error, Error.t()}` - Validation error
  """
  @callback validate(serialized(), keyword()) ::
    :ok | {:error, Error.t()}

  @doc """
  Migrates serialized data from one version to another.

  ## Parameters
    * `data` - The serialized event data to migrate
    * `from_version` - The current version of the data
    * `to_version` - The target version
    * `opts` - Optional migration options

  ## Returns
    * `{:ok, serialized}` - Successfully migrated data
    * `{:error, Error.t()}` - Migration error
  """
  @callback migrate(serialized(), version(), version(), keyword()) ::
    {:ok, serialized()} | {:error, Error.t()}

  @optional_callbacks [migrate: 4]
end
