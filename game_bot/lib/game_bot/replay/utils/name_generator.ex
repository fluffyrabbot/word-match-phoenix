defmodule GameBot.Replay.Utils.NameGenerator do
  @moduledoc """
  Generates memorable, unique names for game replays.

  Each replay name consists of a randomly selected word from the dictionary
  and a random 3-digit number, formatted as `{word}-{number}`.

  For example: "banana-742", "elephant-159", "guitar-305"

  The module ensures uniqueness by checking existing names in the database
  and retrying with a different combination if a collision is detected.
  """

  alias GameBot.Repo
  import Ecto.Query

  @dictionary_path "priv/dictionary.txt"
  # Minimum and maximum word length to consider from dictionary
  @min_word_length 4
  @max_word_length 10

  @doc """
  Generates a unique, memorable name for a replay.

  ## Examples
      iex> NameGenerator.generate()
      {:ok, "banana-742"}

      iex> NameGenerator.generate()
      {:ok, "elephant-159"}
  """
  @spec generate() :: {:ok, String.t()} | {:error, term()}
  def generate do
    with {:ok, words} <- load_dictionary(),
         word <- select_random_word(words),
         number <- generate_random_number(),
         name <- format_name(word, number),
         {:ok, name} <- ensure_unique(name, words) do
      {:ok, name}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Loads the dictionary file and filters words by desired length.

  ## Returns
  - `{:ok, [String.t()]}` - List of valid words
  - `{:error, reason}` - If dictionary can't be loaded
  """
  @spec load_dictionary() :: {:ok, [String.t()]} | {:error, term()}
  def load_dictionary do
    path = Application.app_dir(:game_bot, @dictionary_path)

    case File.read(path) do
      {:ok, content} ->
        words = content
        |> String.split("\n", trim: true)
        |> Enum.filter(&valid_word?/1)

        {:ok, words}

      {:error, reason} ->
        {:error, {:dictionary_error, reason}}
    end
  end

  @doc """
  Selects a random word from the filtered dictionary.
  """
  @spec select_random_word([String.t()]) :: String.t()
  def select_random_word(words) do
    Enum.random(words)
    |> String.downcase()
  end

  @doc """
  Generates a random 3-digit number between 100 and 999.
  """
  @spec generate_random_number() :: integer()
  def generate_random_number do
    Enum.random(100..999)
  end

  @doc """
  Formats a word and number into a replay name.
  """
  @spec format_name(String.t(), integer()) :: String.t()
  def format_name(word, number) do
    "#{word}-#{number}"
  end

  @doc """
  Ensures the generated name is unique by checking against existing replays.
  If a collision is detected, tries a new name.

  ## Parameters
  - `name` - The generated name to check
  - `words` - List of dictionary words (to avoid reloading)

  ## Returns
  - `{:ok, name}` - If name is unique
  - `{:error, reason}` - If unable to generate a unique name after max attempts
  """
  @spec ensure_unique(String.t(), [String.t()], integer()) :: {:ok, String.t()} | {:error, term()}
  def ensure_unique(name, words, attempts \\ 1) do
    max_attempts = 10

    # Query to check if name exists
    name_exists? = Repo.exists?(
      from r in "game_replays",
      where: r.display_name == ^name,
      select: 1
    )

    cond do
      # Name is unique, return it
      not name_exists? ->
        {:ok, name}

      # Max attempts reached, give up
      attempts >= max_attempts ->
        {:error, :max_attempts_reached}

      # Try again with new name
      true ->
        new_word = select_random_word(words)
        new_number = generate_random_number()
        new_name = format_name(new_word, new_number)
        ensure_unique(new_name, words, attempts + 1)
    end
  end

  @doc """
  Checks if a word is valid for use in replay names.

  Word requirements:
  - Length between @min_word_length and @max_word_length
  - Contains only lowercase letters
  - No offensive words (could add filter list)
  """
  @spec valid_word?(String.t()) :: boolean()
  def valid_word?(word) do
    word_length = String.length(word)
    word_lowercase = String.downcase(word)

    # Basic validation
    word_length >= @min_word_length and
    word_length <= @max_word_length and
    # Only contains lowercase letters
    word_lowercase == word and
    # Regex to ensure only a-z characters
    Regex.match?(~r/^[a-z]+$/, word)
    # Add offensive word filter here if needed
  end
end
