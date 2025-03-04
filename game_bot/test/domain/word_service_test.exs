﻿defmodule GameBot.Domain.WordServiceTest do
  use ExUnit.Case
  alias GameBot.Domain.WordService

  setup do
    # Start the WordService for testing
    start_supervised!(WordService)
    :ok
  end

  test "loads dictionary successfully" do
    result = WordService.load_dictionary()
    assert {:ok, count} = result
    assert count > 0
  end

  test "validates words correctly" do
    # Ensure dictionary is loaded first
    {:ok, _} = WordService.load_dictionary()

    # Test with known words from dictionary
    assert WordService.valid_word?("cat")
    assert WordService.valid_word?("dog")

    # Test case-insensitivity
    assert WordService.valid_word?("CAT")

    # Test with non-existent word
    refute WordService.valid_word?("xyzabc123")
  end

  test "generates random words" do
    # Ensure dictionary is loaded first
    {:ok, _} = WordService.load_dictionary()

    word = WordService.random_word()
    assert is_binary(word)
    assert String.length(word) > 0

    {word1, word2} = WordService.random_word_pair()
    assert is_binary(word1)
    assert is_binary(word2)
    assert String.length(word1) > 0
    assert String.length(word2) > 0
  end

  test "matches exact words" do
    # Ensure dictionary is loaded first
    {:ok, _} = WordService.load_dictionary()

    # Exact match, different case
    assert WordService.match?("cat", "cat")
    assert WordService.match?("cat", "CAT")
  end

  test "matches US/UK spelling variations" do
    # Ensure dictionary is loaded first
    {:ok, _} = WordService.load_dictionary()

    # US/UK spelling variations
    assert WordService.match?("color", "colour")
    assert WordService.match?("center", "centre")
  end

  test "matches singular/plural forms" do
    # Ensure dictionary is loaded first
    {:ok, _} = WordService.load_dictionary()

    # Singular/plural forms
    assert WordService.match?("cat", "cats")
    assert WordService.match?("dog", "dogs")
  end

  test "matches lemmatized forms" do
    # Ensure dictionary is loaded first
    {:ok, _} = WordService.load_dictionary()

    # Lemmatization (base forms)
    assert WordService.match?("run", "running")
    assert WordService.match?("walk", "walked")
  end

  test "does not match unrelated words" do
    # Ensure dictionary is loaded first
    {:ok, _} = WordService.load_dictionary()

    # Unrelated words
    refute WordService.match?("cat", "dog")
    refute WordService.match?("run", "swimming")
  end

  test "returns variations of a word" do
    # US/UK spelling variations
    variations = WordService.variations("color")
    assert "colour" in variations

    # Plural forms
    variations = WordService.variations("cat")
    assert "cats" in variations
  end

  test "returns base form of a word" do
    assert WordService.base_form("running") == "run"
    assert WordService.base_form("walked") == "walk"
    assert WordService.base_form("cats") == "cat"
  end
end
