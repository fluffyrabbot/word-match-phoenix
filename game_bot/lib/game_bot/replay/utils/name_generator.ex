defmodule GameBot.Replay.Utils.NameGenerator do
  @moduledoc """
  Generates unique memorable names for replays.

  This module implements the {word}-{3-digit-number} naming pattern,
  creating display names that are:
  - Easy to remember
  - URL safe
  - Collision resistant
  - User-friendly
  """

  require Logger

  @dictionary_path "priv/dictionary.txt"
  @max_retries 10

  @doc """
  Generates a unique replay name.

  ## Parameters
    - existing_names: Optional list of names to avoid
    - opts: Additional options
      - :prefix - Custom prefix to use (default: none)
      - :max_retries - Maximum number of attempts (default: 10)

  ## Returns
    - {:ok, name} - Successfully generated name
    - {:error, reason} - Failed to generate name
  """
  @spec generate_name(list(String.t()) | nil, keyword()) :: {:ok, String.t()} | {:error, term()}
  def generate_name(existing_names \\ nil, opts \\ []) do
    # Load the dictionary
    with {:ok, words} <- load_dictionary() do
      max_retries = Keyword.get(opts, :max_retries, @max_retries)
      prefix = Keyword.get(opts, :prefix, nil)

      # Try to generate a unique name
      do_generate_name(words, existing_names, prefix, max_retries)
    end
  end

  @doc """
  Checks if a name follows the expected format.

  ## Parameters
    - name: The name to validate

  ## Returns
    - true - Valid name format
    - false - Invalid name format
  """
  @spec valid_name_format?(String.t()) :: boolean()
  def valid_name_format?(name) do
    # Validates names in format "word-123"
    Regex.match?(~r/^[a-z]+-\d{3}$/, name)
  end

  @doc """
  Validates a name against a list of existing names (case insensitive).

  ## Parameters
    - name: The name to check
    - existing_names: List of names to check against

  ## Returns
    - :ok - Name is unique
    - {:error, :name_collision} - Name already exists
  """
  @spec validate_unique(String.t(), list(String.t())) :: :ok | {:error, :name_collision}
  def validate_unique(name, existing_names) do
    lowercase_name = String.downcase(name)

    if existing_names && Enum.any?(existing_names, fn existing ->
      String.downcase(existing) == lowercase_name
    end) do
      {:error, :name_collision}
    else
      :ok
    end
  end

  # Private Functions

  # Attempt to generate a unique name, retrying if needed
  defp do_generate_name(_words, _existing_names, _prefix, 0) do
    {:error, :max_retries_exceeded}
  end

  defp do_generate_name(words, existing_names, prefix, retries) do
    name = create_name(words, prefix)

    if existing_names do
      case validate_unique(name, existing_names) do
        :ok -> {:ok, name}
        {:error, _} -> do_generate_name(words, existing_names, prefix, retries - 1)
      end
    else
      {:ok, name}
    end
  end

  # Generate a single name
  defp create_name(words, prefix) do
    word = Enum.random(words)
    number = :rand.uniform(900) + 99  # 100-999

    if prefix do
      "#{prefix}-#{word}-#{number}"
    else
      "#{word}-#{number}"
    end
  end

  # Load dictionary file
  defp load_dictionary do
    app_dir = Application.app_dir(:game_bot)
    dictionary_path = Path.join(app_dir, @dictionary_path)

    case File.read(dictionary_path) do
      {:ok, content} ->
        words = content
          |> String.split("\n", trim: true)
          |> Enum.map(&String.trim/1)
          |> Enum.filter(&(String.length(&1) > 0))

        if Enum.empty?(words) do
          Logger.error("Dictionary file is empty: #{dictionary_path}")
          {:error, :empty_dictionary}
        else
          {:ok, words}
        end

      {:error, reason} ->
        Logger.error("Failed to read dictionary file: #{inspect(reason)}")
        {:error, :dictionary_not_found}
    end
  end
end
