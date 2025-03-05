defmodule GameBot.Domain.WordService do
  @moduledoc """
  Provides core functionality for word management and matching in the WordMatch game mode.

  Key features:
  - Dictionary loading and management
  - Word validation
  - Random word generation
  - Word matching (including variations, plurals, and lemmatization)
  - Optimized caching for expensive operations
  """
  use GenServer
  require Logger

  # Cache tables for expensive operations
  @word_match_cache :word_match_cache      # For match? results
  @variations_cache :word_variations_cache  # For word variations
  @base_form_cache :base_form_cache        # For lemmatization results
  @cache_ttl :timer.hours(24)              # Cache entries expire after 24 hours

  # Irregular verb forms
  @irregular_verbs %{
    "be" => ["am", "is", "are", "was", "were", "been", "being"],
    "run" => ["ran", "running", "runs"],
    "go" => ["went", "gone", "going", "goes"],
    "do" => ["did", "done", "doing", "does"],
    "have" => ["has", "had", "having"],
    "see" => ["saw", "seen", "seeing", "sees"],
    "eat" => ["ate", "eaten", "eating", "eats"],
    "take" => ["took", "taken", "taking", "takes"],
    "make" => ["made", "making", "makes"],
    "come" => ["came", "coming", "comes"]
  }

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

    # Initialize ETS tables with TTL support
    :ets.new(@word_match_cache, [:set, :public, :named_table,
      {:read_concurrency, true}, {:write_concurrency, true}])
    :ets.new(@variations_cache, [:set, :public, :named_table,
      {:read_concurrency, true}, {:write_concurrency, true}])
    :ets.new(@base_form_cache, [:set, :public, :named_table,
      {:read_concurrency, true}, {:write_concurrency, true}])

    # Start cache cleanup process
    schedule_cache_cleanup()

    # Load dictionary
    dictionary_result = do_load_dictionary(dictionary_file)

    # Load word variations
    variations_result = do_load_variations(variations_file)

    case {dictionary_result, variations_result} do
      {{:ok, words, count}, {:ok, variations}} ->
        # Precompute variations for all words
        Task.start(fn -> precompute_variations(words, variations) end)

        {:ok, %{
          dictionary: words,
          word_count: count,
          variations: variations
        }}

      {{:error, reason}, _} ->
        Logger.error("Failed to load dictionary: #{inspect(reason)}")
        {:stop, reason}

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
            {:stop, reason}
        end
    end
  end

  @impl true
  def handle_call({:load_dictionary, filename}, _from, state) do
    case do_load_dictionary(filename) do
      {:ok, words, count} ->
        new_state = %{state | dictionary: words, word_count: count}
        {:reply, {:ok, count}, new_state}

      {:error, _reason} = error ->
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

    result = case lookup_cache(@word_match_cache, cache_key) do
      {:ok, cached_result} ->
        cached_result
      :miss ->
        # No cache hit, calculate the match
        match_result = do_match(word1, word2, state)
        cache_result(@word_match_cache, cache_key, match_result)
        match_result
    end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:variations, word}, _from, state) do
    result = do_variations(word, state)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:base_form, word}, _from, state) do
    result = do_base_form(word)
    {:reply, result, state}
  end

  @impl true
  def handle_info(:cleanup_cache, state) do
    cleanup_expired_cache_entries()
    schedule_cache_cleanup()
    {:noreply, state}
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
    base1 = do_base_form(w1)
    base2 = do_base_form(w2)

    cond do
      # Exact match (case-insensitive)
      w1 == w2 -> true

      # Check if one is a variation of the other
      Enum.member?(do_variations(w1, state), w2) -> true
      Enum.member?(do_variations(w2, state), w1) -> true

      # Check if they share the same base form
      base1 != "" and base2 != "" and (base1 == base2 or base1 in do_variations(base2, state) or base2 in do_variations(base1, state)) -> true

      # Check irregular verb forms
      check_irregular_verbs(w1, w2) -> true

      # No match
      true -> false
    end
  end

  defp precompute_variations(words, file_variations) do
    Logger.info("Starting variation precomputation...")

    words
    |> Enum.each(fn word ->
      variations = do_variations(word, %{variations: file_variations})
      :ets.insert(@variations_cache, {word, variations})
    end)

    Logger.info("Variation precomputation complete")
  end

  defp do_variations(word, state) do
    word = String.downcase(word)

    case lookup_cache(@variations_cache, word) do
      {:ok, variations} -> variations
      :miss ->
        variations = compute_variations(word, state)
        cache_result(@variations_cache, word, variations)
        variations
    end
  end

  defp add_plural_variations(variations) do
    Enum.flat_map(variations, fn word ->
      cond do
        String.ends_with?(word, "s") ->
          [word, String.slice(word, 0..-2//1)]
        String.ends_with?(word, "es") and String.length(word) > 3 ->
          [word, String.slice(word, 0..-3//1)]
        true ->
          [word, word <> "s"]
      end
    end)
  end

  defp add_verb_variations(variations, original) do
    case Map.get(@irregular_verbs, original) do
      nil ->
        variations ++ Enum.flat_map(variations, fn word ->
          cond do
            String.ends_with?(word, "ing") ->
              [word, String.slice(word, 0..-4//1)]
            String.ends_with?(word, "ed") ->
              [word, String.slice(word, 0..-3//1)]
            true ->
              [word]
          end
        end)
      irregular_forms ->
        variations ++ irregular_forms
    end
  end

  defp add_regional_variations(variations, word) do
    variations ++ Enum.flat_map(variations, fn w ->
      cond do
        String.contains?(w, "or") ->
          [w, String.replace(w, "or", "our")]
        String.contains?(w, "our") ->
          [w, String.replace(w, "our", "or")]
        String.contains?(w, "ize") ->
          [w, String.replace(w, "ize", "ise")]
        String.contains?(w, "ise") ->
          [w, String.replace(w, "ise", "ize")]
        true ->
          [w]
      end
    end)
  end

  # Check if two words are related through irregular verb forms
  defp check_irregular_verbs(word1, word2) do
    Enum.any?(@irregular_verbs, fn {base, forms} ->
      (word1 == base or word1 in forms) and (word2 == base or word2 in forms)
    end)
  end

  defp do_base_form(word) do
    word = String.downcase(word)

    case lookup_cache(@base_form_cache, word) do
      {:ok, base} -> base
      :miss ->
        base = compute_base_form(word)
        cache_result(@base_form_cache, word, base)
        base
    end
  end

  # Cache management functions

  defp lookup_cache(table, key) do
    case :ets.lookup(table, key) do
      [{^key, value, expiry}] ->
        if DateTime.compare(expiry, DateTime.utc_now()) == :gt do
          {:ok, value}
        else
          :miss
        end
      [] -> :miss
    end
  end

  defp cache_result(table, key, value) do
    expiry = DateTime.add(DateTime.utc_now(), @cache_ttl, :millisecond)
    :ets.insert(table, {key, value, expiry})
  end

  defp schedule_cache_cleanup do
    Process.send_after(self(), :cleanup_cache, :timer.hours(1))
  end

  defp cleanup_expired_cache_entries do
    now = DateTime.utc_now()
    cleanup_table(@word_match_cache, now)
    cleanup_table(@variations_cache, now)
    cleanup_table(@base_form_cache, now)
  end

  defp cleanup_table(table, now) do
    :ets.select_delete(table, [{
      {:"$1", :"$2", :"$3"},
      [{:<, :"$3", now}],
      [true]
    }])
  end

  # Move existing variation computation to separate function
  defp compute_variations(word, state) do
    # Get variations from file
    file_variations = Map.get(state.variations, word, [])

    # Generate pattern-based variations
    pattern_variations =
      [word]
      |> add_plural_variations()
      |> add_verb_variations(word)
      |> add_regional_variations(word)
      |> MapSet.new()
      |> MapSet.delete(word)  # Remove the original word
      |> MapSet.to_list()

    # Combine and deduplicate variations
    (file_variations ++ pattern_variations)
    |> Enum.uniq()
    |> Enum.reject(&is_nil/1)
  end

  # Move existing base form computation to separate function
  defp compute_base_form(word) do
    # Check irregular verbs first
    case find_irregular_base(word) do
      nil ->
        cond do
          # -ing form
          String.ends_with?(word, "ing") ->
            base = String.slice(word, 0, String.length(word) - 3)
            if String.length(base) > 2 do
              # Handle doubled consonants (e.g., running -> run)
              if String.length(base) > 3 && String.at(base, -1) == String.at(base, -2) do
                String.slice(base, 0, String.length(base) - 1)
              else
                # Try with 'e' at the end
                base <> "e"
              end
            else
              word
            end

          # -ed form
          String.ends_with?(word, "ed") ->
            base = String.slice(word, 0, String.length(word) - 2)
            if String.length(base) > 2 do
              # Handle doubled consonants (e.g., stopped -> stop)
              if String.length(base) > 3 && String.at(base, -1) == String.at(base, -2) do
                String.slice(base, 0, String.length(base) - 1)
              else
                # Try with 'e' at the end
                base <> "e"
              end
            else
              word
            end

          # -s form (plural)
          String.ends_with?(word, "s") and not String.ends_with?(word, "ss") ->
            if String.ends_with?(word, "es") and String.length(word) > 3 do
              String.slice(word, 0, String.length(word) - 2)
            else
              String.slice(word, 0, String.length(word) - 1)
            end

          # No change needed
          true -> word
        end

      base -> base
    end
  end

  # Find the base form of an irregular verb
  defp find_irregular_base(word) do
    Enum.find_value(@irregular_verbs, fn {base, forms} ->
      if word == base or word in forms, do: base, else: nil
    end)
  end

  # Creates a normalized cache key for consistent lookups regardless of word order
  defp cache_key(word1, word2) do
    [a, b] = Enum.sort([String.downcase(word1), String.downcase(word2)])
    "#{a}:#{b}"
  end
end
