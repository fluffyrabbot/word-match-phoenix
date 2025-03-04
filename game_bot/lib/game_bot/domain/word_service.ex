﻿defmodule GameBot.Domain.WordService do
  @moduledoc """
  Provides core functionality for word management and matching in the WordMatch game mode.

  Key features:
  - Dictionary loading and management
  - Word validation
  - Random word generation
  - Word matching (including variations, plurals, and lemmatization)
  """
  use GenServer
  require Logger

  # Client API

  @doc """
  Starts the WordService GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Loads a dictionary from a specified file.
  """
  def load_dictionary(filename \\ "dictionary.txt") do
    GenServer.call(__MODULE__, {:load_dictionary, filename})
  end

  @doc """
  Checks if a word exists in the dictionary.
  """
  def valid_word?(word) do
    GenServer.call(__MODULE__, {:valid_word?, word})
  end

  @doc """
  Generates a random word from the dictionary.
  """
  def random_word do
    GenServer.call(__MODULE__, :random_word)
  end

  @doc """
  Generates a pair of random words for gameplay.
  """
  def random_word_pair do
    GenServer.call(__MODULE__, :random_word_pair)
  end

  @doc """
  Determines if two words are considered a match according to game rules.
  Takes into account spelling variations, singular/plural forms, and word lemmatization.
  """
  def match?(word1, word2) do
    GenServer.call(__MODULE__, {:match?, word1, word2})
  end

  @doc """
  Returns all variations of a word (plurals, regional spellings, etc.).
  """
  def variations(word) do
    GenServer.call(__MODULE__, {:variations, word})
  end

  @doc """
  Returns the base form (lemma) of a word.
  """
  def base_form(word) do
    GenServer.call(__MODULE__, {:base_form, word})
  end

  # Server callbacks

  @impl true
  def init(opts) do
    dictionary_file = Keyword.get(opts, :dictionary_file, "dictionary.txt")
    variations_file = Keyword.get(opts, :variations_file, "word_variations.json")

    # Initialize ETS table for caching match results
    :ets.new(:word_match_cache, [:set, :public, :named_table])

    # Load dictionary
    dictionary_result = do_load_dictionary(dictionary_file)

    # Load word variations
    variations_result = do_load_variations(variations_file)

    case {dictionary_result, variations_result} do
      {{:ok, words, count}, {:ok, variations}} ->
        {:ok, %{
          dictionary: words,
          word_count: count,
          variations: variations
        }}

      {{:error, reason}, _} ->
        Logger.error("Failed to load dictionary: #{inspect(reason)}")
        {:ok, %{
          dictionary: MapSet.new(),
          word_count: 0,
          variations: %{}
        }}

      {_, {:error, reason}} ->
        Logger.error("Failed to load word variations: #{inspect(reason)}")

        case dictionary_result do
          {:ok, words, count} ->
            {:ok, %{
              dictionary: words,
              word_count: count,
              variations: %{}
            }}
          _ ->
            {:ok, %{
              dictionary: MapSet.new(),
              word_count: 0,
              variations: %{}
            }}
        end
    end
  end

  @impl true
  def handle_call({:load_dictionary, filename}, _from, state) do
    case do_load_dictionary(filename) do
      {:ok, words, count} ->
        new_state = %{state | dictionary: words, word_count: count}
        {:reply, {:ok, count}, new_state}

      {:error, reason} = error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:valid_word?, word}, _from, %{dictionary: dict} = state) do
    # Case-insensitive check
    result = word |> String.downcase() |> then(&MapSet.member?(dict, &1))
    {:reply, result, state}
  end

  @impl true
  def handle_call(:random_word, _from, %{dictionary: dict, word_count: count} = state) do
    if count > 0 do
      # Convert dictionary to list for random selection
      words = MapSet.to_list(dict)
      random_word = Enum.random(words)
      {:reply, random_word, state}
    else
      {:reply, nil, state}
    end
  end

  @impl true
  def handle_call(:random_word_pair, _from, %{dictionary: dict, word_count: count} = state) do
    if count > 0 do
      # Convert dictionary to list for random selection
      words = MapSet.to_list(dict)
      word1 = Enum.random(words)
      word2 = Enum.random(words)
      {:reply, {word1, word2}, state}
    else
      {:reply, {nil, nil}, state}
    end
  end

  @impl true
  def handle_call({:match?, word1, word2}, _from, state) do
    cache_key = cache_key(word1, word2)

    result = case :ets.lookup(:word_match_cache, cache_key) do
      [{_, cached_result}] ->
        cached_result
      [] ->
        # No cache hit, calculate the match
        match_result = do_match(word1, word2, state)
        :ets.insert(:word_match_cache, {cache_key, match_result})
        match_result
    end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:variations, word}, _from, state) do
    variations = do_variations(word, state)
    {:reply, variations, state}
  end

  @impl true
  def handle_call({:base_form, word}, _from, state) do
    base = do_base_form(word)
    {:reply, base, state}
  end

  # Private functions

  defp do_load_dictionary(filename) do
    path = Application.app_dir(:game_bot, "priv/dictionaries/#{filename}")

    case File.read(path) do
      {:ok, content} ->
        words = content
                |> String.split("\n")
                |> Enum.map(&String.downcase/1)
                |> Enum.filter(&(String.trim(&1) != ""))
                |> MapSet.new()

        {:ok, words, MapSet.size(words)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_load_variations(filename) do
    path = Application.app_dir(:game_bot, "priv/dictionaries/#{filename}")

    case File.read(path) do
      {:ok, content} ->
        try do
          variations = Jason.decode!(content)
          {:ok, variations}
        rescue
          e ->
            Logger.error("Failed to parse variations JSON: #{inspect(e)}")
            {:error, :invalid_json}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Word matching logic - checks for exact match, variations, plurals, and lemmatization
  defp do_match(word1, word2, state) do
    w1 = String.downcase(word1)
    w2 = String.downcase(word2)

    cond do
      # Exact match (case-insensitive)
      w1 == w2 -> true

      # Check if one is a variation of the other
      Enum.member?(do_variations(w1, state), w2) -> true
      Enum.member?(do_variations(w2, state), w1) -> true

      # Check if they share the same base form
      do_base_form(w1) == do_base_form(w2) && do_base_form(w1) != "" -> true

      # No match
      true -> false
    end
  end

  # Get word variations using both pattern matching and loaded variations file
  defp do_variations(word, %{variations: variations} = _state) do
    w = String.downcase(word)

    # Combine all variations (original word, known variations from JSON, pattern-based variations, and plurals)
    [w | (get_known_variations(w, variations) ++
          get_pattern_variations(w) ++
          get_plural_variations(w))]
  end

  # Get variations from JSON file
  defp get_known_variations(word, variations) do
    Map.get(variations, word, [])
  end

  # Get variations based on common spelling patterns
  defp get_pattern_variations(word) do
    cond do
      # -ize to -ise (and vice versa)
      String.ends_with?(word, "ize") ->
        [String.slice(word, 0..-4) <> "ise"]
      String.ends_with?(word, "ise") ->
        [String.slice(word, 0..-4) <> "ize"]

      # -or to -our (and vice versa)
      String.ends_with?(word, "or") and not String.ends_with?(word, "ior") ->
        [word <> "u"]
      String.ends_with?(word, "our") ->
        [String.slice(word, 0..-2)]

      true -> []
    end
  end

  # Get plural variations of a word
  defp get_plural_variations(word) do
    cond do
      # Add 's' (e.g., cat -> cats)
      word =~ ~r/[^s]$/ -> ["#{word}s"]

      # Remove 's' (e.g., cats -> cat)
      word =~ ~r/s$/ -> [String.slice(word, 0..-2)]

      true -> []
    end
  end

  # Simple lemmatization (base form extraction)
  defp do_base_form(word) do
    w = String.downcase(word)

    cond do
      # -ing form
      String.ends_with?(w, "ing") ->
        base = String.slice(w, 0..-4)
        if String.length(base) > 2, do: base, else: w

      # -ed form
      String.ends_with?(w, "ed") ->
        base = String.slice(w, 0..-3)
        if String.length(base) > 2, do: base, else: w

      # -s form (plural)
      String.ends_with?(w, "s") and not String.ends_with?(w, "ss") ->
        String.slice(w, 0..-2)

      # No change needed
      true -> w
    end
  end

  # Creates a normalized cache key for consistent lookups regardless of word order
  defp cache_key(word1, word2) do
    [a, b] = Enum.sort([String.downcase(word1), String.downcase(word2)])
    "#{a}:#{b}"
  end
end
